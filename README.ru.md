# NGMusic
<img width="2160" height="1080" alt="Picsart_26-09-22_14-13-50-119" src="https://github.com/user-attachments/assets/70199b32-7fd9-4732-a8ec-e77aa689683b" />

[English](README.md) | **Русский**

Мобильный плеер для [Newgrounds Audio Portal](https://www.newgrounds.com/audio) — неофициальный клиент, имеющий большой функционал и возможности. Тот же NG Audio Portal, но в виде удобного приложения.

## Что умеет

- **Каталог и поиск:** хабы (Featured / Popular / New / Top Rated), поиск по трекам с подгрузкой страниц при скролле
- **Плеер:** стриминг mp3, очередь, автопереход к следующему треку, мини-плеер, фоновое воспроизведение
- **Оценки:** голосование 0–5 звёзд с шагом 0.5 для Modern, и по цельным звездам для Classic оболочки
- **Избранное и плейлисты:** добавление треков в избранное на аккаунте Newgrounds, локальные плейлисты
- **Аккаунт:** вход в Newgrounds, просмотр своей библиотеки плейлистов и возможность их создания
- **Артисты:** страницы исполнителей с их треками
- **Скачивание:** загрузка mp3 на устройство

Данные тянутся напрямую с newgrounds.com: HTML парсится локально, аудио стримится с CDN Newgrounds.

## Стек

- Flutter / Dart, min SDK — Android 5.0 (API 21)
- `http` + `html` для загрузки и парсинга страниц
- Media3 (ExoPlayer + MediaSessionService) для воспроизведения и фонового режима
- `provider` для состояния (`ChangeNotifier`)
- `sqflite` как основа для локальной библиотеки (избранное, плейлисты)
- `webview_flutter` для входа в аккаунт Newgrounds

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
│   └── ng_audio_handler.dart          # Аудио-хендлер (мост к нативному плееру Media3)
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
