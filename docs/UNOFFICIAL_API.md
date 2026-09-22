# Newgrounds Audio Portal — Unofficial API

Неофициальная документация внутреннего API аудио-портала Newgrounds.
Собрана реверс-инжинирингом веб-клиента (HTML, JS, сетевые запросы) в
сентябре 2026 для приложения [NGMusic](https://github.com/G2961/NgMusic_alpha).
Официального публичного API у Newgrounds **нет**.

> ⚠️ Дисклеймер: это приватные, незадокументированные endpoints. Newgrounds
> может изменить их в любой момент без уведомления (уже менял — см.
> «История изменений формата»). Используйте разумно, соблюдайте rate-limit
> и [Terms of Use](https://www.newgrounds.com/wiki/creator-resources/terms-of-use).

---

## Содержание

1. [Общие положения](#общие-положения) — базовый URL, заголовки, куки, CSRF
2. [Аутентификация](#аутентификация) — Passport, куки, userkey
3. [Каталог и ленты](#каталог-и-ленты) — Featured / Browse / Popular / Top Rated
4. [Трек](#трек) — страница listen, метаданные, mp3, мой голос
5. [Поиск](#поиск) — полнотекстовый и по ID
6. [Артист](#артист) — профиль, треки, подписка
7. [Отзывы](#отзывы) — список, создание, правка, удаление, ответы
8. [Голосование](#голосование) — оценка трека (votebar)
9. [Избранное](#избранное) — фаворитинг треков
10. [Плейлисты](#плейлисты) — облачные плейлисты аккаунта
11. [Служебные](#служебные) — visual-links, load-component
12. [Грабли](#грабли) — 419, ротация кук, парсинг
13. [История изменений формата](#история-изменений-формата)

---

## Общие положения

### Базовые адреса

| Хост | Назначение |
|---|---|
| `https://www.newgrounds.com` | основной сайт, все endpoint'ы кроме артист-страниц |
| `https://{username}.newgrounds.com` | поддомен артиста (профиль, `/audio`) |
| `https://audio.ngfiles.com/{folder}/` | CDN mp3-файлов, `folder = floor(id / 1000) * 1000` |
| `https://aicon.ngfiles.com/{folder}/` | CDN обложек, `folder = floor(id / 1000)` |
| `https://img.ngfiles.com/` | картинки, загруженные пользователями |

### Заголовки

NG отдаёт контент по-разному в зависимости от User-Agent; мобильный UA
проверен и работает:

```
User-Agent: Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Mobile Safari/537.36
```

Для AJAX-запросов (всё, что возвращает JSON или HTML-фрагменты):

```
X-Requested-With: XMLHttpRequest
Accept: application/json, text/javascript, */*; q=0.01
Content-Type: application/x-www-form-urlencoded; charset=UTF-8
```

Часть страниц (артист-лента, диалоги) требует `X-Requested-With` даже на GET.

### Куки

Полная сессионная кука — строка вида:

```
ng_session=…; ng_remember=…; ng_user0=…; XSRF-TOKEN=…; newgrounds_session=…
```

- `newgrounds_session` — HttpOnly, выдаётся **в том числе анонимным
  посетителям**. По её наличию нельзя определить, залогинен ли пользователь.
- Кука ротируется сервером: **каждый GET может вернуть `Set-Cookie`** с
  обновлённой сессией. Для последующих POST-запросов нужно мержить
  обновления (см. [Грабли → 419](#грабли)).

### CSRF-токен

На каждой странице есть мета-тег:

```html
<meta name="csrf-token" content="NiZ1eFflg5QQEvqYU0VY4OUmhEwYhlPw6zixFwZX">
```

jQuery сайта вставляет его в каждый AJAX заголовком:

```
X-CSRF-TOKEN: {csrf-token}
```

Токен привязан к сессии: беру́т токен из одного GET, а шлют POST с другой
кукой → **419** (Laravel token mismatch).

### userkey (uek)

Короткоживущий токен, нужен **в теле** почти каждого POST. На страницах
встречается в двух видах:

```js
PHP.set('uek', 'ff-g-gC4-aKHh');          // инлайн-скрипт
```
```html
<input type="hidden" name="userkey" value="ff-g-gC4-aKHh">
```

Лёгкий способ достать свежий (страница ~13 КБ вместо ~180 КБ главной):

```
GET /playlists/addentry/{trackId}/3?isAjaxRequest=1
```

Кешировать нельзя — привязан к сессии и протухает.

### `___ng_design`

Аккаунтам с классическим дизайном NG требует в POST-теле флаг выбранного
дизайна: `___ng_design=2015` (или `2024`). Некоторые endpoints без него
работают, некоторые — нет. Безопаснее всегда добавлять.

---

## Аутентификация

Официального OAuth нет. Рабочая схема (используется в NGMusic):

1. Открыть WebView на `https://www.newgrounds.com/account/`
   → незалогиненный получит редирект на Newgrounds Passport,
   пользователь логинится там.
2. После загрузки аккаунт-страницы извлечь имя из `document.title`
   (формат `"Username's Account Page"`) или заголовков `.podhead`.
3. Читать куки **нативно** (`CookieManager` на Android / `WKHTTPCookieStore`
   на iOS) для домена `newgrounds.com` — в `document.cookie` нет
   HttpOnly `newgrounds_session`, а без него ничего не работает.
4. Сохранить строку кук + имя. Проверка «реальной» сессии: запросить
   страницу с кукой и убедиться, что в HTML есть
   `PHP.set('activeuser', {…})` с именем пользователя.

Имя текущего пользователя есть на **любой** странице в инлайн-скрипте:

```js
PHP.set('activeuser', {"name":"g2961", …});
```

---

## Каталог и ленты

Все ленты отдают HTML со списком `<ul class="itemlist">`. Пагинация —
параметром `offset` (кратный 24).

### Featured Audio

```
GET /audio/featured
GET /audio/featured?genre={genreId}&offset={n}
```

### Browse (Latest)

```
GET /audio/browse?genre={genreId}&offset={n}&inner=1
```

`inner=1` отдаёт только список без обвязки страницы.

### Popular

```
GET /audio/popular?genre={genreId}&offset={n}&inner=1
```

### Top Rated

```
GET /audio/browse?sort=score&interval=month&genre={genreId}&offset={n}&inner=1
```

### Формат элемента списка

Каждый `<li>` содержит (селекторы): обложка `img` (`src` — CDN-превью),
заголовок (`.detail-title` / `strong`), автор (`.detail-author`),
жанр-ссылка `a[href*="/audio/browse/tag/"]`, длительность
`[data-audio-duration]` (секунды), ссылка на трек `a[href*="/audio/listen/"]`
— из неё извлекается `id`.

> ID трека и папка CDN связаны: `folder = floor(id/1000)`.

---

## Трек

### Страница прослушивания

```
GET /audio/listen/{trackId}
```

Главный источник метаданных. Содержит:

**1. JSON `preload-data`** (инлайн-скрипт):

```js
'song': {
  'filename': '1572356_DPI-filtration.mp3',   // полное имя файла
  'score': 4.78, 'votes': 26, 'listens': 3754,
  'bpm': 174, 'genre': 'Hip Hop - Olskool',
  'icon': 'https://aicon.ngfiles.com/1572/1572356_medium.webp?f…',
  'images': { 'listen': { … } },
  'duration': 82, 'loop': false,
  'integrated_lufs': -8.7, 'peak_dbfs': 0.5, 'loudness_range_lu': 9.5,
  'version': 1779923422,
}
```

Полный URL mp3: `https://audio.ngfiles.com/{folder}/{filename}`.

**2. `dl.sidestats`** — Listens / Faves / Downloads / Votes / Score /
Uploaded / Genre / File Info. Если голосов < 5, вместо балла в Score
текст `Waiting for N more votes` — публичного балла у трека нет.

**3. Теги** — ссылки `a[href*="/audio/browse/tag/{tag}"]`.

**4. Награды** — `ul.trophies > li`, класс `li` — тип награды
(`frontpage`, `daily1`, `weekly1`, `monthly4`, `review`…), внутри
`<strong>Название</strong>` и дата.

**5. Мой голос** — если голосовал, в votebar-е стоит `checked`-радио:

```html
<input type="radio" name="vote" id="votebar-10" value="10" checked />
```

`value` — голос в шкале 0..10. Без голоса `checked` нет вообще.
Это **надёжный источник** собственной оценки (NG после голосования
убирает votebar со страницы, но `checked` в HTML сохраняется).

**6. Author Comments** — блок `#author_comments` с HTML внутри
(абзацы `<p>`, `<br>`, `b/strong/i/em/u/a`, `blockquote`, `ul/ol`,
картинки `img[src*="img.ngfiles.com"]` с атрибутом `data-smart-scale="W,H"`)
— исходные размеры картинки. Пустая строка на NG — `<p><br/></p>`.

**7. Кнопка избранного** — см. [Избранное](#избранное).

**8. og-мета** — `og:title`, `og:audio` (полный mp3-URL), `og:image`.
Лёгкий разбор без preload-data: og-теги + артист из
`.item-details-main h4 a`.

### Кандидаты обложки (от лучшего к худшему)

```
https://aicon.ngfiles.com/{folder}/{id}_raw.png    # исходник автора
https://aicon.ngfiles.com/{folder}/{id}_raw.jpg
https://aicon.ngfiles.com/{folder}/{id}_full.webp  # из og:image / song.icon
https://aicon.ngfiles.com/{folder}/{id}_medium.webp
```

---

## Поиск

### Полнотекстовый

```
GET /search/conduct/audio?suitabilities=etma&c=3&terms={query}
GET /search/conduct/audio?suitabilities=etma&c=3&terms={query}&page={n}
```

`page` с 1, по 24 элемента. Разметка — тот же `ul.itemlist`.
Заголовок «Author - Title» стоит нормализовать: если начинается с
`{author} - `, отрезать префикс.

### По ID

`GET /audio/listen/{id}` — трек по числовому ID напрямую (см. [Трек](#трек)).
Удобно для ID из Geometry Dash.

---

## Артист

### Профиль

```
GET https://{username}.newgrounds.com
```

Поддомен отдаёт 301, если автор переименовался — **ходите по финальному
URL** (ключи кнопок валидны только для нового хоста). Кука обязательна,
иначе гость: не будет ни `activeuser`, ни follow-кнопки.

Содержит: аватар (`og:image`), `dl.sidestats`/`dl.userdata`
(Age/Gender/Country/Joined/Level/Exp), счётчики `a.user-header-button`
(`FANS`, `AUDIO`), кнопку подписки (см. ниже).

### Лента треков

```
GET https://{username}.newgrounds.com/audio?page={n}
```

⚠️ При заголовке `X-Requested-With: XMLHttpRequest` отдаёт **JSON**:

```json
{
  "items": { "2026": [ "<html-строки карточек…>", … ], … },
  "load_more": "…href=\"https://user.newgrounds.com/audio?page=2\"…"
}
```

Карточки — `a.item-audiosubmission` (id из href, обложка, title).
`load_more` пуст — страниц больше нет.

### Подписка (follow)

Кнопка на странице артиста:

```html
<span class="favefollow-buttons[ active]" id="ffr_ffr_{hash}_{n}">
  <a href="#" title="Follow" class="follow-user"><span>Follow</span></a>
  <a href="#" title="Unfollow" class="following-user"><span>Following</span></a>
</span>
<script>
  ngutils.initFollowButton("#ffr_ffr_{hash}_{n}", "{userkey}",
    {"store":"https://www.newgrounds.com/favorites/users/{uid}/follow",
     "destroy":"https://www.newgrounds.com/favorites/users/{uid}/follow"});
</script>
```

- **Статус подписки** — класс `active` на `span.favefollow-buttons`.
  Первый аргумент `initFollowButton` — jQuery-селектор **с решёткой**,
  в DOM id без неё. Оба состояния (Follow/Following) есть в разметке
  всегда — видимость переключает CSS. Класс `active` — единственный
  надёжный признак.
- **Подписаться** — `POST {store}` с телом `userkey={userkey}&___ng_design=2015`
- **Отписаться** — `POST {destroy}` с тем же телом (URL один, различие
  только в том, какой из двух скрипт отдал; метод — всегда POST, см.
  `legacy.js → ajaxifyLink`)

Ответ: JSON со статусом. Старый формат `/favorites/follow/add/{key}` —
удалён, отдаёт 404.

---

## Отзывы

### Список

```
GET /reviews/portal/{trackId}/3/{sort}/{page}
```

- `sort`: `date` | `score`
- Сортировка только по убыванию; для возрастания зеркальте страницы:
  логическая страница 1 (старейшие) = последняя страница NG, развёрнутая.
- `page` с 1. Общее количество страниц: `<span>Page</span> N of M`.
- **Требуется кука**: гостю NG отдаёт пустую колонку (не ошибку!).
- ⚠️ При частых запросах NG отвечает **429** без тела — обрабатывайте.

Карточка отзыва:

```html
<div class="review" data-review-id="32488916" …>
  <a href="https://{user}.newgrounds.com">…<span>Имя</span></a>
  <time>2026-08-31 11:35:46</time>
  <a class="ngicon-25-flag" href="/flag/add/N/2003" title="Report Abuse">
  <span class="score"><div class="star-score" title="Score: 5.00/5.00">
  <div class="review-body">…текст…</div>
  <div class="authresponse">…ответ автора трека…</div>
</div>
```

Ответ автора (`div.authresponse`) есть только у отзывов на свои треки.

### Свой отзыв

На странице трека `/audio/listen/{id}`: карточка с кнопкой карандаша
`href="/reviews/edit/{reviewId}"` — признак существования твоего отзыва.
Отзыв с оценкой: `title="Score: 5.00/5.00"` внутри карточки.

### Создание

```
POST /reviews/create/{trackId}/3
Content-Type: application/x-www-form-urlencoded

userkey={userkey}&generic_id={trackId}&type_id=3&vote={0..10}&body={text}
```

`vote` — 0..10 (полузвёзды), `0` = без оценки. Успех — 302 обратно на
страницу трека. Ошибка NG возвращается текстом в теле.

### Правка

```
GET  /reviews/edit/{reviewId}     # форма, userkey предзаполнен
POST /reviews/edit/{reviewId}

userkey={userkey}&generic_id={trackId}&type_id=3&vote={0..10}&body={text}
```

### Удаление

```
GET /reviews/delete/{reviewId}
```

Да, GET выполняет удаление (в браузере — страница подтверждения, но
прямой GET тоже удаляет).

### Ответ автора на отзыв

Форма доступна **только автору трека** (это же и проверка владения):

```
GET  /reviews/responses/create/{reviewId}    # форма с userkey
POST /reviews/responses/create/{reviewId}

userkey={userkey}&body={text}
```

### Жалоба

`GET /flag/add/{type}/{id}` — страница подтверждения; на сайте
открывается в диалоге. Из приложения проще открыть во внешнем браузере.

---

## Голосование

### Поставить оценку треку

```
POST /content/vote/{trackId}/3

show_fields=1&userkey={userkey}&vote={0..10}
```

- `vote` — 0..10 (полузвёзды; 5 = максимум, «5 звёзд»)
- Заголовок `X-CSRF-TOKEN` обязателен.
- Ответ JSON, HTML-фрагмент внутри содержит обновлённый сайдбар:

```json
{ "sidestats": "<… id=\"score_number\">4.79 …<dt>Votes</dt><dd>27</dd>…" }
```

Если голосов всё ещё < 5, во фрагменте текст `Waiting for N more votes`.

### Шкала оценок

UI votebar — 6 лиц (0..5 звёзд), внутри всё в полузвёздах 0..10.
Пустая оценка (без звёзд) — `vote=0`.

---

## Избранное

Кнопка на странице трека (`initFavoriteButton`):

```html
<span class="favefollow-buttons[ active]" id="ffr_ffr_{hash}_{n}">…</span>
<script>
  ngutils.initFavoriteButton("#ffr_ffr_{hash}_{n}", "{userkey}", "{buttonKey}");
</script>
```

⚠️ На авторизованной странице трека 2026 инлайн-скрипта может не быть —
кнопка подтягивается компонентом
`GET /projects/audio/{projectId}/load-component/users`
(`projectId` ≠ `trackId`, извлекается из страницы). Гостю компонент
отдаёт 302.

**Статус**: класс `active` на обёртке (аналогично подписке).

### Переключить

```
POST /favorites/audio/{trackId}/favorite
X-CSRF-TOKEN: {token}

body: "___ng_design=2015"  — добавить
body: ""                   — убрать
```

Ответ: `{"active":true,"fave_type":"favorite", …}`.

Старый формат `POST /favorites/{type}/{add|remove}/{buttonKey}` с телом
`userkey=…` тоже встречается (2024-разметка) — ответ
`{"active":bool,"fave_type":"favorite",…}` или
400 `Illegal communication attempt` без userkey.

---

## Плейлисты

### Список плейлистов пользователя

```
GET https://{username}.newgrounds.com/playlists[?page={n}]
```

⚠️ Страница отдаёт **пустышки**:

```html
<li data-visual-link="[21000,{playlistId}]"></li>
```

Названия и обложки дорисовываются через `visual-links-fetch`
(см. [Служебные](#служебные)).

### Треки плейлиста

```
GET /playlist/{playlistId}
```

Тот же приём: пустышки `data-visual-link="[3,{trackId}]"` +
`visual-links-fetch`.

### Диалог добавления

```
GET /playlists/addentry/{trackId}/3?isAjaxRequest=1
```

HTML: `<select name="playlist_id">` с последними 20 плейлистами +
скрытый `userkey`. Удобный лёгкий источник и того, и другого.

### Добавить трек

```
POST /playlists/addentry

id={trackId}&type=3&userkey={userkey}&playlist_id={playlistId}
```

или для нового плейлиста:

```
id={trackId}&type=3&userkey={userkey}&title={New Playlist Name}
```

Ответ при успехе — HTML-под «Added to playlist!» со ссылкой
`/playlist/{id}` (id нового плейлиста берут из неё).

**Создать пустой плейлист нельзя**: endpoint требует существующий
`id` трека, иначе 400 `Invalid/missing id`. Обход: создать с любым
треком-затравкой и сразу удалить запись.

### Удалить запись

Записи адресуются собственным `entryId` (не id трека!). Со страницы
`GET /playlists/edit/{playlistId}`:

```html
<li data-id="8095137" data-pos="1" data-visual-link="[3,1564606]">
```

`entryId` = `data-id`, где `data-visual-link` = `[3,{trackId}]`.

```
POST /playlists/entry/delete/{entryId}

userkey={userkey}
```

Ответ: `{"success":true}`.

### Переименовать

```
POST /playlists/edit/{playlistId}

userkey={userkey}&title={New Title}
```

Ответ: `{"success":true,"data":{…}}`.

### Удалить плейлист

```
POST /playlists/delete/{playlistId}

userkey={userkey}
```

Ответ: `{"url":"…/playlists"}` (редирект-указание).

---

## Служебные

### visual-links-fetch

```
POST /visual-links-fetch
Content-Type: application/x-www-form-urlencoded

visual_links[]={type},{id}&visual_links[]={type},{id}…
```

Дорисовывает пустышки `data-visual-link="[type,id]"` настоящей
разметкой. Ответ:

```json
{"success":true,"partials":{"{type}":{"{id}":"<li>…</li>"}}}
```

`type`: `3` — аудио-трек, `21000` — плейлист.

### load-component

```
GET /projects/audio/{projectId}/load-component/users
```

HTML-фрагмент с кнопкой избранного (см. [Избранное](#избранное)).

### Компоненты автора_комментариев и прочие

```
GET /projects/audio/{projectId}/load-component/author_comments
```

Используется редактором NG; для чтения достаточно страницы трека.

---

## Грабли

### 419 и ротация кук

Laravel за NG на каждый GET может **ротировать сессию** (`Set-Cookie`
в ответе). POST с «протухшей» кукой и CSRF из свежего HTML → 419.
Рецепт:

1. GET страницы → из тела достаём CSRF и данные.
2. Из заголовка ответа `Set-Cookie` достаём пары `name=value` и
   **мержим** в сохранённую куку (заменяем существующие имена).
3. POST шлём со слитой кукой + `X-CSRF-TOKEN` из тела GET.

### Определение «залогинен ли»

По кукам нельзя: `newgrounds_session` выдаётся и анонимам. Только
запрос страницы с проверкой `PHP.set('activeuser', …)`.

### Парсинг пустых строк NG

Пустой абзац в Author Comments — `<p><br /></p>`, а не отсутствие
узла. При конвертации в текст `br` нельзя считать контентом, иначе
получите лишние пустые строки.

### Сжатые URL в JSON

Внутри JSON/JS атрибутов NG экранирует слэши: `"https:\/\/…"` —
перед использованием заменяйте `\/` → `/`.

### HTML-сущности

Имена, тексты отзывов и комменты экранированы (`&amp;`, `&#039;`…)
— декодировать обязательно.

### «Один POST — одно действие»

POST-эндпоинты избранного/подписки **переключают** состояние, а не
устанавливают. Чтобы поставить нужное, а не инвертировать: сначала
прочитать `active`, и слать POST только если состояние отличается.

### Rate limiting

При агрессивной частоте запросов NG начинает отвечать 429 (тело
пустое). Особенно чувствителен `/reviews/portal`. Разумные паузы и
ретраи с экспоненциальной задержкой обязательны.

### Guest-режим

Многие страницы для гостя отдают 200 с урезанной разметкой (без
кнопок/компонентов), а не 401/403. Проверяйте наличие конкретных
узлов, а не код ответа.

---

## История изменений формата

Формат меняется без предупреждения. Задокументированные смены:

| Когда | Что изменилось |
|---|---|
| ~2024 | Старый формат `favefollow`: инлайн-скрипт `initFavoriteButton("#id", "userkey", "buttonKey")` |
| 2026-05 | Появился `POST /favorites/audio/{id}/favorite` (фаворитинг без ключа кнопки); `/projects/audio/{pid}/load-component/users` подтягивает кнопки отдельным запросом |
| 2026-08 | `/favorites/follow/add/{key}` удалён (404). Подписка переехала на `initFollowButton("#id", "userkey", {"store":url,"destroy":url})` с прямыми URL `/favorites/users/{uid}/follow`; оба действия — POST с `userkey` в теле |

---

*Документация собрана из исходников
[NGMusic](https://github.com/G2961/NgMusic_alpha) — Flutter-клиента
аудио-портала. Реализация всех описанных вызовов:
`lib/data/repository/ng_repository.dart`.*
