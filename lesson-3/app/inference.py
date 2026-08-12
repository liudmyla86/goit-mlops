"""
app/inference.py

Виконує inference зображення за допомогою TorchScript-моделі MobileNetV2.

Використання:
    python3 app/inference.py <шлях_до_зображення>

Приклад:
    python3 app/inference.py example.jpg
"""

import sys
from pathlib import Path

import torch
from PIL import Image
from torchvision.models import MobileNet_V2_Weights

MODEL_PATH = Path(__file__).resolve().parent.parent / "model" / "model.pt"


def load_model(model_path: Path = MODEL_PATH):
    """Завантажує TorchScript-модель і переводить її у режим eval."""
    model = torch.jit.load(str(model_path), map_location="cpu")
    model.eval()
    return model


def predict(image_path: str, model_path: Path = MODEL_PATH, top_k: int = 3):
    """Повертає top_k передбачень (клас + впевненість) для зображення."""
    weights = MobileNet_V2_Weights.DEFAULT
    preprocess = weights.transforms()
    categories = weights.meta["categories"]

    image = Image.open(image_path).convert("RGB")
    input_tensor = preprocess(image).unsqueeze(0)  # додаємо batch-вимір

    model = load_model(model_path)

    with torch.no_grad():
        output = model(input_tensor)
        probabilities = torch.nn.functional.softmax(output[0], dim=0)

    top_probs, top_idxs = torch.topk(probabilities, top_k)

    results = []
    for prob, idx in zip(top_probs, top_idxs):
        class_id = idx.item()
        class_name = categories[class_id] if class_id < len(categories) else "unknown"
        results.append((class_id, class_name, prob.item()))

    return results


def main():
    if len(sys.argv) != 2:
        print("Використання: python3 app/inference.py <шлях_до_зображення>")
        sys.exit(1)

    image_path = sys.argv[1]

    if not Path(image_path).is_file():
        print(f"Помилка: файл '{image_path}' не знайдено.")
        sys.exit(1)

    if not MODEL_PATH.is_file():
        print(f"Помилка: модель не знайдено за шляхом '{MODEL_PATH}'. "
              f"Спочатку запустіть export_model.py.")
        sys.exit(1)

    results = predict(image_path)

    print(f"Top-{len(results)} передбачення для '{image_path}':")
    for rank, (class_id, class_name, prob) in enumerate(results, start=1):
        print(f"  {rank}. class_id={class_id:>3}  {class_name:<30}  confidence={prob:.4f}")


if __name__ == "__main__":
    main()
