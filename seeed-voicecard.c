/*
 * ASoC driver for seeed-voicecard
 *
 * Author: Baozhu Zuo <zuobaozhu@gmail.com>
 * Copyright (C) 2017 Seeed Technology Inc.
 * Copyright (C) 2023 Адаптация для Orange Pi Zero 2W
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 */

#include <linux/module.h>
#include <linux/platform_device.h>

#include <sound/core.h>
#include <sound/pcm.h>
#include <sound/pcm_params.h>
#include <sound/soc.h>
#include <sound/jack.h>

static int snd_rpi_seeed_voicecard_init(struct snd_soc_pcm_runtime *rtd)
{
    return 0;
}

static int snd_rpi_seeed_voicecard_hw_params(struct snd_pcm_substream *substream,
                         struct snd_pcm_hw_params *params)
{
    struct snd_soc_pcm_runtime *rtd = substream->private_data;
    struct snd_soc_dai *cpu_dai = rtd->cpu_dai;

    unsigned int sample_bits =
        snd_pcm_format_physical_width(params_format(params));

    return snd_soc_dai_set_bclk_ratio(cpu_dai, sample_bits * 2);
}

/* machine stream operations */
static struct snd_soc_ops snd_rpi_seeed_voicecard_ops = {
    .hw_params = snd_rpi_seeed_voicecard_hw_params,
};

static struct snd_soc_dai_link snd_rpi_seeed_voicecard_dai[] = {
    {
        .name = "seeed-2mic-voicecard",
        .stream_name = "seeed-2mic-voicecard",
        .codec_dai_name = "wm8960-hifi",
        .dai_fmt = SND_SOC_DAIFMT_I2S | SND_SOC_DAIFMT_NB_NF |
            SND_SOC_DAIFMT_CBS_CFS,
        .ops = &snd_rpi_seeed_voicecard_ops,
        .init = &snd_rpi_seeed_voicecard_init,
    },
    {
        .name = "seeed-4mic-voicecard",
        .stream_name = "seeed-4mic-voicecard",
        .codec_dai_name = "wm8960-hifi",
        .dai_fmt = SND_SOC_DAIFMT_I2S | SND_SOC_DAIFMT_NB_NF |
            SND_SOC_DAIFMT_CBS_CFS,
        .ops = &snd_rpi_seeed_voicecard_ops,
        .init = &snd_rpi_seeed_voicecard_init,
    },
    {
        .name = "seeed-8mic-voicecard",
        .stream_name = "seeed-8mic-voicecard",
        .codec_dai_name = "ac108-pcm",
        .codec_name = "ac108.1-003b",
        .dai_fmt = SND_SOC_DAIFMT_I2S | SND_SOC_DAIFMT_NB_NF |
            SND_SOC_DAIFMT_CBS_CFS,
        .ops = &snd_rpi_seeed_voicecard_ops,
        .init = &snd_rpi_seeed_voicecard_init,
    },
};

/* audio machine driver */
static struct snd_soc_card snd_rpi_seeed_voicecard = {
    .name = "seeed-voicecard",
    .owner = THIS_MODULE,
    .dai_link = snd_rpi_seeed_voicecard_dai,
    .num_links = ARRAY_SIZE(snd_rpi_seeed_voicecard_dai),
};

static int snd_rpi_seeed_voicecard_probe(struct platform_device *pdev)
{
    int ret = 0;
    struct snd_soc_card *card = &snd_rpi_seeed_voicecard;
    struct device_node *np = pdev->dev.of_node;
    struct device_node *i2s_node;
    struct snd_soc_dai_link *dai;

    card->dev = &pdev->dev;

    /* Определение платформы и настроек */
    if (of_machine_is_compatible("allwinner,sun50i-h618") ||
        of_machine_is_compatible("allwinner,sun50i-h616")) {
        /* Настройки для Orange Pi Zero 2W */
        if (pdev->name) {
            /* Для возможности поддержки разных карт в будущем */
            if (strcmp(pdev->name, "seeed-2mic-voicecard") == 0)
                dai = &snd_rpi_seeed_voicecard_dai[0];
            else if (strcmp(pdev->name, "seeed-4mic-voicecard") == 0)
                dai = &snd_rpi_seeed_voicecard_dai[1];
            else if (strcmp(pdev->name, "seeed-8mic-voicecard") == 0)
                dai = &snd_rpi_seeed_voicecard_dai[2];
            else {
                /* По умолчанию выбираем 4-микрофонную карту для Orange Pi */
                dai = &snd_rpi_seeed_voicecard_dai[1];
                card->name = "seeed-4mic-voicecard";
            }
        } else {
            /* По умолчанию выбираем 4-микрофонную карту для Orange Pi */
            dai = &snd_rpi_seeed_voicecard_dai[1];
            card->name = "seeed-4mic-voicecard";
        }

        i2s_node = of_parse_phandle(np, "i2s-controller", 0);
        if (!i2s_node) {
            dev_err(&pdev->dev, "Свойство i2s-controller не найдено в DT\n");
            of_node_put(i2s_node);
            return -EINVAL;
        }

        /* Настройка для Orange Pi Zero 2W */
        dai->cpus = devm_kzalloc(&pdev->dev, sizeof(struct snd_soc_dai_link_component), GFP_KERNEL);
        if (!dai->cpus)
            return -ENOMEM;

        dai->platforms = devm_kzalloc(&pdev->dev, sizeof(struct snd_soc_dai_link_component), GFP_KERNEL);
        if (!dai->platforms)
            return -ENOMEM;

        dai->codecs = devm_kzalloc(&pdev->dev, sizeof(struct snd_soc_dai_link_component), GFP_KERNEL);
        if (!dai->codecs)
            return -ENOMEM;

        /* Настраиваем линки для SoC Orange Pi */
        dai->num_cpus = 1;
        dai->num_platforms = 1;
        dai->num_codecs = 1;
        dai->cpus->of_node = i2s_node;
        dai->cpus->dai_name = NULL;
        dai->platforms->of_node = i2s_node;
        dai->codecs->dai_name = "wm8960-hifi";
        dai->codecs->name = "wm8960.1-001a";

        of_node_put(i2s_node);
    } else {
        /* Настройки для других платформ - используем старый подход */
        dai = &snd_rpi_seeed_voicecard_dai[0];

        i2s_node = of_parse_phandle(np, "i2s-controller", 0);
        if (!i2s_node) {
            dev_err(&pdev->dev, "Свойство i2s-controller не найдено в DT\n");
            return -EINVAL;
        }

        dai->cpu_of_node = i2s_node;
        dai->platform_of_node = i2s_node;
        dai->codec_name = "wm8960.1-001a";
        
        of_node_put(i2s_node);
    }

    /* Регистрация карты */
    ret = devm_snd_soc_register_card(&pdev->dev, card);
    if (ret && ret != -EPROBE_DEFER)
        dev_err(&pdev->dev, "Не удалось зарегистрировать звуковую карту: %d\n", ret);

    return ret;
}

static const struct of_device_id snd_rpi_seeed_voicecard_of_match[] = {
    { .compatible = "seeed,seeed-voicecard", },
    {},
};
MODULE_DEVICE_TABLE(of, snd_rpi_seeed_voicecard_of_match);

static struct platform_driver snd_rpi_seeed_voicecard_driver = {
    .driver = {
        .name = "seeed-voicecard",
        .owner = THIS_MODULE,
        .of_match_table = snd_rpi_seeed_voicecard_of_match,
    },
    .probe = snd_rpi_seeed_voicecard_probe,
};

module_platform_driver(snd_rpi_seeed_voicecard_driver);

MODULE_AUTHOR("Baozhu Zuo <zuobaozhu@gmail.com>");
MODULE_DESCRIPTION("ASoC Driver for Seeed Voice Card");
MODULE_LICENSE("GPL v2");
