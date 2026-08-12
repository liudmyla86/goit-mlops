"""
export_model.py

Завантажує попередньо натреновану модель MobileNetV2 з torchvision (сучасний
API `weights=...`), переводить її в режим інференсу (`eval()`) і серіалізує
у формат TorchScript (`torch.jit.trace`) для подальшого використання у
fat- та slim-образах.

Результат зберігається у: model/model.pt
"""

from pathlib import Path

import torch
from torchvision.models import MobileNet_V2_Weights, mobilenet_v2


def export_model(output_path: str = "model/model.pt") -> None:
    output_file = Path(output_path)
    output_file.parent.mkdir(parents=True, exist_ok=True)

    # 1. Завантажуємо ваги ImageNet (сучасний API замість pretrained=True)
    weights = MobileNet_V2_Weights.DEFAULT
    model = mobilenet_v2(weights=weights)

    # 2. Переводимо модель у режим інференсу (вимикає dropout/batchnorm-тренування)
    model.eval()

    # 3. Створюємо dummy input того ж формату, що очікує модель (1x3x224x224)
    dummy_input = torch.randn(1, 3, 224, 224)

    # 4. Трасуємо модель у TorchScript
    with torch.no_grad():
        traced_model = torch.jit.trace(model, dummy_input)

    # 5. Зберігаємо модель
    traced_model.save(str(output_file))

    print(f"Модель успішно експортовано у TorchScript: {output_file}")
    print(f"Категорій класифікації: {len(weights.meta['categories'])}")


if __name__ == "__main__":
    export_model()
