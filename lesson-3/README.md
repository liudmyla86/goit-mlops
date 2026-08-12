# Домашнє завдання №3 — Контейнеризація ML-моделі (fat vs slim)

Проєкт демонструє повний MLOps-цикл для простої inference-задачі:
підготовка середовища → експорт моделі у TorchScript → написання
inference-скрипта → побудова двох Docker-образів (fat / slim) →
порівняння результатів і розмірів образів.

Модель: **MobileNetV2** (ImageNet, 1000 класів) з `torchvision.models`,
експортована у формат **TorchScript** (`torch.jit.trace`).

## Структура проєкту

```
lesson-3/
├── app/
│   └── inference.py        # inference-скрипт (top-3 передбачення)
├── model/
│   └── model.pt             # TorchScript-модель (створюється export_model.py)
├── scripts/
│   └── install_dev_tools.sh # перевірка/підготовка середовища
├── export_model.py          # експорт MobileNetV2 -> TorchScript
├── requirements.txt         # torch / torchvision / pillow
├── Dockerfile.fat            # "важкий" образ (python:3.13)
├── Dockerfile.slim           # оптимізований multi-stage образ (python:3.13-slim)
├── .dockerignore
├── example.jpg               # тестове зображення
├── report.md                  # порівняння fat vs slim
└── README.md
```

## Вимоги

- Docker + Docker Compose V2 (`docker compose version`)
- Python **3.13**+
- pip3
- Пакети: `torch`, `torchvision`, `pillow` (версії — див. `requirements.txt`)

## 1. Підготовка середовища

```bash
bash scripts/install_dev_tools.sh
```

Скрипт ідемпотентний: перевіряє наявність Docker, Docker Compose V2,
Python ≥ 3.13, pip та ML-бібліотек; те, чого бракує, намагається
встановити автоматично або виводить точну інструкцію. Усі результати
записуються у `install.log`.

## 2. Локальна перевірка (без Docker)

Встановити залежності:

```bash
pip3 install -r requirements.txt
```

Експортувати модель у TorchScript:

```bash
python3 export_model.py
# -> створює model/model.pt
```

Запустити inference локально:

```bash
python3 app/inference.py example.jpg
```

Приклад виводу:

```
Top-3 передбачення для 'example.jpg':
  1. class_id=281  tabby cat                       confidence=0.4123
  2. class_id=282  tiger cat                        confidence=0.2210
  3. class_id=285  Egyptian cat                     confidence=0.0876
```

*(конкретні значення залежать від вмісту `example.jpg`)*

## 3. Збірка Docker-образів

Fat-образ (простий, python:3.13, одна стадія):

```bash
docker build -f Dockerfile.fat -t ml-infer-fat:1.0 .
```

Slim-образ (multi-stage, python:3.13-slim):

```bash
docker build -f Dockerfile.slim -t ml-infer-slim:1.0 .
```

## 4. Запуск інференсу в контейнерах

Обидва образи вже містять `example.jpg` і `model/model.pt` усередині
(скопійовані під час збірки), тому їх можна запускати без bind mount:

```bash
docker run --rm ml-infer-fat:1.0
docker run --rm ml-infer-slim:1.0
```

Або явно передати інше зображення через bind mount:

```bash
docker run --rm -v "$(pwd)/example.jpg:/app/example.jpg" ml-infer-fat:1.0 example.jpg
docker run --rm -v "$(pwd)/example.jpg:/app/example.jpg" ml-infer-slim:1.0 example.jpg
```

Результати top-3 передбачень мають збігатися (або відрізнятись лише в
межах незначної числової похибки), оскільки обидва образи
використовують той самий файл `model/model.pt`.

## 5. Порівняння образів

```bash
docker images | grep ml-infer
docker history ml-infer-fat:1.0
docker history ml-infer-slim:1.0
```

Деталі та висновки — у [`report.md`](./report.md).

## 6. Скріншоти (обов'язково)

Додайте сюди 4 скріншоти реальних запусків на вашій машині —
це підтвердження, що код дійсно виконувався, а не лише написаний:

1. **Збірка обох образів** (`docker build -f Dockerfile.fat ...` та
   `docker build -f Dockerfile.slim ...`, повний вивід до `Successfully built`):

   `![build fat](./screenshots/01_build_fat.png)`
   `![build slim](./screenshots/02_build_slim.png)`

2. **Запуск контейнерів** (`docker run ...` для обох образів):

   `![run fat](./screenshots/03_run_fat.png)`
   `![run slim](./screenshots/04_run_slim.png)`

3. **Результат inference** — top-3 класи на екрані для обох образів
   (може бути той самий скріншот, що й пункт 2, якщо вивід top-3
   видно на ньому):

   `![inference result](./screenshots/05_inference_result.png)`

4. **`docker images | grep ml-infer`** з видимими розмірами обох образів:

   `![docker images](./screenshots/06_docker_images.png)`

Створіть папку `screenshots/` поруч із цим README і покладіть туди
файли з відповідними іменами — тоді картинки в цьому файлі
відобразяться автоматично на GitHub.

## Джерело example.jpg

`example.jpg` — синтетичне тестове RGB-зображення 224×224,
згенероване локально (`PIL` + `numpy`, детермінований seed=42), що
використовується виключно для перевірки коректності роботи
inference-пайплайна (однаковість результату fat/slim-образів). Для
змістовного прикладу класифікації рекомендується підмінити цей файл
власною фотографією (наприклад, кота, собаки чи іншого об'єкта з
набору ImageNet-класів) перед фінальною демонстрацією.

## Примітка щодо середовища розробки

Дана репозиторна структура була підготовлена та частково перевірена
у пісочниці без Docker і без доступу до `download.pytorch.org`
(звідки завантажуються попередньо натреновані ваги MobileNetV2).
Через це:

- логіка `export_model.py` та `app/inference.py` перевірена локально
  (Python 3.12, з тимчасово незавантаженими / випадковими вагами
  лише для тестування самого пайплайна трасування й inference);
- фактична збірка `docker build` та реальні розміри образів у
  `report.md` **потребують запуску на машині з Docker і доступом до
  інтернету** (Docker Hub + download.pytorch.org) — команди в цьому
  README готові до копіювання й запуску “як є”.

Перед здачею обов'язково виконайте кроки 1–5 на своїй машині та
підставте реальні цифри (розмір образів, кількість шарів, час
збірки) у `report.md`.
