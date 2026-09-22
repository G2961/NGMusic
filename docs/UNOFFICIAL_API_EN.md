# Newgrounds Audio Portal — Unofficial API

Unofficial documentation of the Newgrounds Audio Portal's internal API.
Compiled by reverse-engineering the web client (HTML, JS, network
traffic) in September 2026 for the
[NGMusic](https://github.com/G2961/NgMusic_alpha) app. Newgrounds has
**no** official public API.

> ⚠️ Disclaimer: these are private, undocumented endpoints. Newgrounds
> can change them at any time without notice (and has — see the
> [Format changelog](#format-changelog)). Use responsibly, respect
> rate limits and the
> [Terms of Use](https://www.newgrounds.com/wiki/creator-resources/terms-of-use).

---

## Contents

1. [General](#general) — base URLs, headers, cookies, CSRF
2. [Authentication](#authentication) — Passport, cookies, userkey
3. [Catalog & feeds](#catalog--feeds) — Featured / Browse / Popular / Top Rated
4. [Track](#track) — listen page, metadata, mp3, my vote
5. [Search](#search) — full-text and by ID
6. [Artist](#artist) — profile, tracks, following
7. [Reviews](#reviews) — list, create, edit, delete, author responses
8. [Voting](#voting) — rating a track (votebar)
9. [Favorites](#favorites) — favoriting tracks
10. [Playlists](#playlists) — account cloud playlists
11. [Utilities](#utilities) — visual-links, load-component
12. [Pitfalls](#pitfalls) — 419, cookie rotation, parsing
13. [Format changelog](#format-changelog)

---

## General

### Base URLs

| Host | Purpose |
|---|---|
| `https://www.newgrounds.com` | main site, every endpoint except artist pages |
| `https://{username}.newgrounds.com` | artist subdomain (profile, `/audio`) |
| `https://audio.ngfiles.com/{folder}/` | mp3 CDN, `folder = floor(id / 1000) * 1000` |
| `https://aicon.ngfiles.com/{folder}/` | artwork CDN, `folder = floor(id / 1000)` |
| `https://img.ngfiles.com/` | user-uploaded images |

### Headers

NG serves different content depending on User-Agent; the mobile one is
tested and works:

```
User-Agent: Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Mobile Safari/537.36
```

For AJAX requests (anything that returns JSON or HTML fragments):

```
X-Requested-With: XMLHttpRequest
Accept: application/json, text/javascript, */*; q=0.01
Content-Type: application/x-www-form-urlencoded; charset=UTF-8
```

Some pages (artist feed, dialogs) require `X-Requested-With` even on GET.

### Cookies

The full session cookie string looks like:

```
ng_session=…; ng_remember=…; ng_user0=…; XSRF-TOKEN=…; newgrounds_session=…
```

- `newgrounds_session` is HttpOnly and is issued **to anonymous visitors
  too**. Its presence alone does not mean the user is logged in.
- The server **rotates the cookie**: every GET may return `Set-Cookie`
  with a fresh session. Subsequent POSTs must merge those updates
  (see [Pitfalls → 419](#pitfalls)).

### CSRF token

Every page carries a meta tag:

```html
<meta name="csrf-token" content="NiZ1eFflg5QQEvqYU0VY4OUmhEwYhlPw6zixFwZX">
```

The site's jQuery sends it with every AJAX request as a header:

```
X-CSRF-TOKEN: {csrf-token}
```

The token is bound to the session: taking the token from one GET and
sending the POST with a different cookie → **419** (Laravel token mismatch).

### userkey (uek)

A short-lived token required **in the body** of almost every POST.
It appears on pages in two forms:

```js
PHP.set('uek', 'ff-g-gC4-aKHh');          // inline script
```
```html
<input type="hidden" name="userkey" value="ff-g-gC4-aKHh">
```

A lightweight way to get a fresh one (~13 KB page instead of the ~180 KB
front page):

```
GET /playlists/addentry/{trackId}/3?isAjaxRequest=1
```

Do not cache it — it is session-bound and expires.

### `___ng_design`

For accounts on the classic design, NG expects a design flag in POST
bodies: `___ng_design=2015` (or `2024`). Some endpoints work without
it, some don't. Safest to always include it.

---

## Authentication

There is no official OAuth. A working scheme (the one NGMusic uses):

1. Open a WebView at `https://www.newgrounds.com/account/`
   → a logged-out user gets redirected to Newgrounds Passport and
   signs in there.
2. Once the account page loads, extract the username from
   `document.title` (format: `"Username's Account Page"`) or from
   `.podhead` headings.
3. Read cookies **natively** (`CookieManager` on Android /
   `WKHTTPCookieStore` on iOS) for the `newgrounds.com` domain —
   `document.cookie` does not expose the HttpOnly `newgrounds_session`,
   and nothing works without it.
4. Store the cookie string + username. To verify a "real" session,
   request a page with the cookie and check that the HTML contains
   `PHP.set('activeuser', {…})` with the username.

The current username is present on **every** page in an inline script:

```js
PHP.set('activeuser', {"name":"g2961", …});
```

---

## Catalog & feeds

All feeds return HTML with a `<ul class="itemlist">`. Pagination uses
the `offset` parameter (multiples of 24).

### Featured Audio

```
GET /audio/featured
GET /audio/featured?genre={genreId}&offset={n}
```

### Browse (Latest)

```
GET /audio/browse?genre={genreId}&offset={n}&inner=1
```

`inner=1` returns just the list without the page chrome.

### Popular

```
GET /audio/popular?genre={genreId}&offset={n}&inner=1
```

### Top Rated

```
GET /audio/browse?sort=score&interval=month&genre={genreId}&offset={n}&inner=1
```

### List item format

Each `<li>` contains (selectors): artwork `img` (`src` is a CDN preview),
title (`.detail-title` / `strong`), author (`.detail-author`), a genre
link `a[href*="/audio/browse/tag/"]`, duration `[data-audio-duration]`
(seconds), and a track link `a[href*="/audio/listen/"]` — the `id` is
extracted from it.

> Track ID maps to CDN folder: `folder = floor(id/1000)`.

---

## Track

### Listen page

```
GET /audio/listen/{trackId}
```

The primary metadata source. Contains:

**1. `preload-data` JSON** (inline script):

```js
'song': {
  'filename': '1572356_DPI-filtration.mp3',   // bare file name
  'score': 4.78, 'votes': 26, 'listens': 3754,
  'bpm': 174, 'genre': 'Hip Hop - Olskool',
  'icon': 'https://aicon.ngfiles.com/1572/1572356_medium.webp?f…',
  'images': { 'listen': { … } },
  'duration': 82, 'loop': false,
  'integrated_lufs': -8.7, 'peak_dbfs': 0.5, 'loudness_range_lu': 9.5,
  'version': 1779923422,
}
```

Full mp3 URL: `https://audio.ngfiles.com/{folder}/{filename}`.

**2. `dl.sidestats`** — Listens / Faves / Downloads / Votes / Score /
Uploaded / Genre / File Info. With fewer than 5 votes the Score field
reads `Waiting for N more votes` — the track has no public score yet.

**3. Tags** — links `a[href*="/audio/browse/tag/{tag}"]`.

**4. Awards** — `ul.trophies > li`; the `li` class is the award type
(`frontpage`, `daily1`, `weekly1`, `monthly4`, `review`…), with
`<strong>Title</strong>` and a date inside.

**5. My vote** — if you have voted, the votebar contains a `checked`
radio:

```html
<input type="radio" name="vote" id="votebar-10" value="10" checked />
```

`value` is the vote on the 0..10 scale. Without a vote there is no
`checked` at all. This is the **reliable source** for your own rating
(NG removes the votebar from the page after voting, but the `checked`
stays in the HTML).

**6. Author Comments** — the `#author_comments` block containing HTML
(paragraphs `<p>`, `<br>`, `b/strong/i/em/u/a`, `blockquote`, `ul/ol`,
images `img[src*="img.ngfiles.com"]` with a `data-smart-scale="W,H"`
attribute holding the original dimensions). A blank line on NG is
`<p><br/></p>`.

**7. Favorite button** — see [Favorites](#favorites).

**8. og-meta** — `og:title`, `og:audio` (full mp3 URL), `og:image`.
A lightweight parse without preload-data: og tags + artist from
`.item-details-main h4 a`.

### Artwork candidates (best to worst)

```
https://aicon.ngfiles.com/{folder}/{id}_raw.png    # author's original
https://aicon.ngfiles.com/{folder}/{id}_raw.jpg
https://aicon.ngfiles.com/{folder}/{id}_full.webp  # from og:image / song.icon
https://aicon.ngfiles.com/{folder}/{id}_medium.webp
```

---

## Search

### Full-text

```
GET /search/conduct/audio?suitabilities=etma&c=3&terms={query}
GET /search/conduct/audio?suitabilities=etma&c=3&terms={query}&page={n}
```

`page` starts at 1, 24 items per page. Markup is the same
`ul.itemlist`. Normalize the "Author - Title" heading: if it starts
with `{author} - `, strip the prefix.

### By ID

`GET /audio/listen/{id}` — fetch a track by numeric ID directly
(see [Track](#track)). Handy for Geometry Dash IDs.

---

## Artist

### Profile

```
GET https://{username}.newgrounds.com
```

The subdomain returns 301 if the artist renamed — **use the final URL**
(button keys are only valid for the new host). A cookie is required,
otherwise you get the guest page: no `activeuser`, no follow button.

Contains: avatar (`og:image`), `dl.sidestats` / `dl.userdata`
(Age/Gender/Country/Joined/Level/Exp), counters in `a.user-header-button`
(`FANS`, `AUDIO`), and the follow button (below).

### Track feed

```
GET https://{username}.newgrounds.com/audio?page={n}
```

⚠️ With the `X-Requested-With: XMLHttpRequest` header this returns
**JSON**:

```json
{
  "items": { "2026": [ "<card html strings…>", … ], … },
  "load_more": "…href=\"https://user.newgrounds.com/audio?page=2\"…"
}
```

Cards are `a.item-audiosubmission` (id from href, artwork, title).
Empty `load_more` means no more pages.

### Following (follow)

The button on the artist page:

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

- **Follow status** — the `active` class on `span.favefollow-buttons`.
  The first `initFollowButton` argument is a jQuery selector **with the
  leading `#`**, while the DOM id has none. Both states (Follow /
  Following) are always present in the markup — CSS toggles visibility.
  The `active` class is the only reliable signal.
- **Follow** — `POST {store}` with body `userkey={userkey}&___ng_design=2015`
- **Unfollow** — `POST {destroy}` with the same body (same URL pattern;
  the difference is which of the two URLs the script hands you; the
  method is always POST — see `legacy.js → ajaxifyLink`)

Response: JSON with the resulting status. The legacy
`/favorites/follow/add/{key}` path is gone — it returns 404 now.

---

## Reviews

### List

```
GET /reviews/portal/{trackId}/3/{sort}/{page}
```

- `sort`: `date` | `score`
- Sorting is descending only; to get ascending, mirror the pages:
  logical page 1 (oldest) = NG's last page, reversed.
- `page` starts at 1. Total pages: `<span>Page</span> N of M`.
- **A cookie is required**: guests get an empty column (not an error).
- ⚠️ Under frequent requests NG answers **429** with an empty body —
  handle it.

A review card:

```html
<div class="review" data-review-id="32488916" …>
  <a href="https://{user}.newgrounds.com">…<span>Name</span></a>
  <time>2026-08-31 11:35:46</time>
  <a class="ngicon-25-flag" href="/flag/add/N/2003" title="Report Abuse">
  <span class="score"><div class="star-score" title="Score: 5.00/5.00">
  <div class="review-body">…text…</div>
  <div class="authresponse">…track author's response…</div>
</div>
```

The author response (`div.authresponse`) only exists on reviews of your
own tracks.

### My review

On the track page `/audio/listen/{id}`: your card has an edit-pencil
link `href="/reviews/edit/{reviewId}"` — the marker that your review
exists. A rated review carries `title="Score: 5.00/5.00"` inside the card.

### Create

```
POST /reviews/create/{trackId}/3
Content-Type: application/x-www-form-urlencoded

userkey={userkey}&generic_id={trackId}&type_id=3&vote={0..10}&body={text}
```

`vote` is 0..10 (half-stars), `0` = no rating. Success is a 302 back to
the track page. NG errors come back as text in the body.

### Edit

```
GET  /reviews/edit/{reviewId}     # form, userkey pre-filled
POST /reviews/edit/{reviewId}

userkey={userkey}&generic_id={trackId}&type_id=3&vote={0..10}&body={text}
```

### Delete

```
GET /reviews/delete/{reviewId}
```

Yes, a GET performs the deletion (in the browser it shows a
confirmation page, but hitting it directly deletes too).

### Author response

The form is available **only to the track author** (which doubles as
the ownership check):

```
GET  /reviews/responses/create/{reviewId}    # form with userkey
POST /reviews/responses/create/{reviewId}

userkey={userkey}&body={text}
```

### Flagging

`GET /flag/add/{type}/{id}` — a confirmation page; on the site it opens
in a dialog. From an app, opening it in an external browser is simplest.

---

## Voting

### Rate a track

```
POST /content/vote/{trackId}/3

show_fields=1&userkey={userkey}&vote={0..10}
```

- `vote` — 0..10 (half-stars; 5 = maximum, "5 stars")
- The `X-CSRF-TOKEN` header is required.
- The JSON response carries the updated sidebar inside an HTML fragment:

```json
{ "sidestats": "<… id=\"score_number\">4.79 …<dt>Votes</dt><dd>27</dd>…" }
```

If there are still fewer than 5 votes, the fragment contains
`Waiting for N more votes`.

### Rating scale

The votebar UI shows six faces (0..5 stars); internally everything is
on the 0..10 half-star scale. An empty rating (no stars) is `vote=0`.

---

## Favorites

The button on the track page (`initFavoriteButton`):

```html
<span class="favefollow-buttons[ active]" id="ffr_ffr_{hash}_{n}">…</span>
<script>
  ngutils.initFavoriteButton("#ffr_ffr_{hash}_{n}", "{userkey}", "{buttonKey}");
</script>
```

⚠️ On the 2026 logged-in track page the inline script may be absent —
the button is fetched separately via
`GET /projects/audio/{projectId}/load-component/users`
(`projectId` ≠ `trackId`, extract it from the page). Guests get a 302
on the component.

**Status**: the `active` class on the wrapper (same as following).

### Toggle

```
POST /favorites/audio/{trackId}/favorite
X-CSRF-TOKEN: {token}

body: "___ng_design=2015"  — add
body: ""                   — remove
```

Response: `{"active":true,"fave_type":"favorite", …}`.

The legacy `POST /favorites/{type}/{add|remove}/{buttonKey}` with body
`userkey=…` also exists (2024 markup) — it answers
`{"active":bool,"fave_type":"favorite",…}` or
400 `Illegal communication attempt` without a userkey.

---

## Playlists

### User's playlists

```
GET https://{username}.newgrounds.com/playlists[?page={n}]
```

⚠️ The page only contains **placeholders**:

```html
<li data-visual-link="[21000,{playlistId}]"></li>
```

Titles and artwork are filled in via `visual-links-fetch`
(see [Utilities](#utilities)).

### Playlist tracks

```
GET /playlist/{playlistId}
```

Same trick: placeholders `data-visual-link="[3,{trackId}]"` +
`visual-links-fetch`.

### Add-entry dialog

```
GET /playlists/addentry/{trackId}/3?isAjaxRequest=1
```

HTML: a `<select name="playlist_id">` with the 20 most recent playlists
plus a hidden `userkey`. A convenient lightweight source for both.

### Add a track

```
POST /playlists/addentry

id={trackId}&type=3&userkey={userkey}&playlist_id={playlistId}
```

or, for a new playlist:

```
id={trackId}&type=3&userkey={userkey}&title={New Playlist Name}
```

On success the response is an HTML pod — "Added to playlist!" with a
`/playlist/{id}` link (grab the new playlist id from it).

**You cannot create an empty playlist**: the endpoint requires an
existing track `id`, otherwise 400 `Invalid/missing id`. Workaround:
create it with any seed track and immediately delete the entry.

### Delete an entry

Entries are addressed by their own `entryId` (not the track id!). From
`GET /playlists/edit/{playlistId}`:

```html
<li data-id="8095137" data-pos="1" data-visual-link="[3,1564606]">
```

`entryId` = `data-id` where `data-visual-link` = `[3,{trackId}]`.

```
POST /playlists/entry/delete/{entryId}

userkey={userkey}
```

Response: `{"success":true}`.

### Rename

```
POST /playlists/edit/{playlistId}

userkey={userkey}&title={New Title}
```

Response: `{"success":true,"data":{…}}`.

### Delete a playlist

```
POST /playlists/delete/{playlistId}

userkey={userkey}
```

Response: `{"url":"…/playlists"}` (a redirect hint).

---

## Utilities

### visual-links-fetch

```
POST /visual-links-fetch
Content-Type: application/x-www-form-urlencoded

visual_links[]={type},{id}&visual_links[]={type},{id}…
```

Fills in the `data-visual-link="[type,id]"` placeholders with real
markup. Response:

```json
{"success":true,"partials":{"{type}":{"{id}":"<li>…</li>"}}}
```

`type`: `3` — audio track, `21000` — playlist.

### load-component

```
GET /projects/audio/{projectId}/load-component/users
```

An HTML fragment with the favorite button (see [Favorites](#favorites)).

### Other components

```
GET /projects/audio/{projectId}/load-component/author_comments
```

Used by NG's editor; for reading, the track page is enough.

---

## Pitfalls

### 419 and cookie rotation

The Laravel stack behind NG may **rotate the session** on every GET
(`Set-Cookie` in the response). A POST with a stale cookie and a CSRF
token from the fresh HTML → 419. Recipe:

1. GET the page → take the CSRF token and data from the body.
2. Take the `name=value` pairs from the response's `Set-Cookie`
   header and **merge** them into your stored cookie (replace existing
   names).
3. Send the POST with the merged cookie + the `X-CSRF-TOKEN` from the
   GET body.

### Detecting "logged in"

Not possible from cookies alone: `newgrounds_session` is issued to
anonymous visitors too. Only request a page and check for
`PHP.set('activeuser', …)`.

### Parsing NG blank lines

A blank paragraph in Author Comments is `<p><br /></p>`, not an absent
node. When converting to text, a `br` must not count as content —
otherwise you get extra blank lines.

### Escaped URLs in JSON

Inside JSON/JS attributes NG escapes slashes: `"https:\/\/…"` —
replace `\/` → `/` before use.

### HTML entities

Names, review texts and comments are escaped (`&amp;`, `&#039;`…) —
always decode.

### "One POST — one toggle"

The favorite/follow POST endpoints **toggle** state rather than set it.
To land on a specific state, read `active` first and only send the POST
when it differs.

### Rate limiting

Under aggressive request rates NG starts answering 429 (empty body).
`/reviews/portal` is especially sensitive. Reasonable pauses and retries
with exponential backoff are a must.

### Guest mode

Many pages return 200 with stripped markup (no buttons/components) for
guests, not 401/403. Check for the presence of specific nodes, not the
status code.

---

## Format changelog

The format changes without notice. Documented shifts:

| When | What changed |
|---|---|
| ~2024 | Legacy `favefollow` format: inline script `initFavoriteButton("#id", "userkey", "buttonKey")` |
| 2026-05 | `POST /favorites/audio/{id}/favorite` appeared (favoriting without a button key); `/projects/audio/{pid}/load-component/users` now delivers the button separately |
| 2026-08 | `/favorites/follow/add/{key}` removed (404). Following moved to `initFollowButton("#id", "userkey", {"store":url,"destroy":url})` with direct `/favorites/users/{uid}/follow` URLs; both actions are POSTs with `userkey` in the body |

---

*Compiled from the sources of
[NGMusic](https://github.com/G2961/NgMusic_alpha), a Flutter client for
the Audio Portal. Working implementations of everything described here:
`lib/data/repository/ng_repository.dart`.*
