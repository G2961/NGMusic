# NGMusic

Мобильный плеер для [Newgrounds Audio Portal](https://www.newgrounds.com/audio) — неофициальный клиент, имеющий выбор между темами — Classic и Modern.
## Что умеет

- **Каталог и поиск** — хабы (Featured, Best / Weekly / Daily / Monthly, Genres), поиск по трекам с подгрузкой страниц при скролле
- **Плеер** — стриминг mp3, очередь, автопереход к следующему треку, мини-плеер, фоновое воспроизведение
- **Оценки** — голосование 0–5 звёзд с шагом 0.5 (жестовая votebar как на сайте: превью-кольцо, полузвёзды, реакции Стива)
- **Избранное и плейлисты** — добавление треков в избранное на аккаунте Newgrounds, локальные плейлисты
- **Аккаунт** — вход в Newgrounds, просмотр своей библиотеки
- **Артисты** — страницы исполнителей с их треками
- **Скачивание** — загрузка mp3 на устройство

Данные тянутся напрямую с newgrounds.com: HTML парсится локально, аудио стримится с CDN Newgrounds.

## Стек

- Flutter / Dart, min SDK — Android 5.0 (API 21)
- `http` + `html` — загрузка и парсинг страниц
- `just_audio` + `audio_service` — воспроизведение и фоновый режим
- `provider` — состояние (`ChangeNotifier`)
- `sqflite` — локальная библиотека (история, плейлисты)
- `webview_flutter` — вход в аккаунт Newgrounds

## Сборка и запуск

```bash
flutter pub get
flutter run                    # дев-режим
flutter build apk --release   # релизный APK
```

Тесты:

```bash
flutter test
```

## Структура

```
lib/
├── data/
│   ├── model/track.dart               # Модель трека
│   └── repository/ng_repository.dart  # Запросы и парсинг newgrounds.com
├── player/
│   └── ng_audio_handler.dart          # Аудио-хендлep (just_audio + audio_service)
├── services/
│   └── track_downloader.dart          # Скачивание mp3
├── ui/
│   ├── screens/                       # Хаб, плеер, библиотека, аккаунт, артисты, поиск
│   ├── widgets/                       # Ретро-виджеты: хром 2015, votebar, мини-плеер
│   └── theme/ng_theme.dart            # NG-палитра и шрифты
├── viewmodel/
│   ├── ng_viewmodel.dart              # Состояние каталога и плеера
│   └── library_viewmodel.dart         # Локальная библиотека
└── main.dart                          # Точка входа
```

## ❗ВАЖНО!❗

Приложение неофициальное и не связано с Newgrounds. Все права на контент принадлежат его авторам и Newgrounds.
