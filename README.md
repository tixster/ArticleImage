# VKArticleImage

CLI-инструмент и набор Swift-библиотек для выгрузки изображений из статей VK и постов Boosty.

Проект собирается как Swift Package и включает:

- библиотеку `VKParser` для статей VK;
- библиотеку `BoostyParser` для постов и подборок Boosty;
- исполняемый CLI `parse` для пакетного запуска из терминала.

## Возможности

- скачивание изображений из одной или нескольких статей VK;
- скачивание диапазона глав VK по шаблонной ссылке;
- скачивание изображений из одной или нескольких публикаций Boosty;
- скачивание всех доступных постов Boosty по тегам;
- сохранение файлов по папкам в `~/Downloads/articles/...`;
- работа с закрытым контентом через аутентификационные данные.

## Требования

- Swift 6.0 или новее;
- macOS 13+ для запуска CLI;
- доступ в интернет;
- действующие данные авторизации для закрытых материалов VK и Boosty.

## Установка и запуск

Сборка проекта:

```bash
swift build
```

Справка по CLI:

```bash
swift run parse --help
```

Запуск локально без `swift run` после сборки:

```bash
.build/arm64-apple-macosx/debug/parse --help
```

## Куда сохраняются файлы

Все изображения сохраняются в папку:

```text
~/Downloads/articles/
```

Далее внутри создаётся подпапка по источнику:

- `~/Downloads/articles/vk`
- `~/Downloads/articles/boosty`

Имена файлов формируются автоматически: изображения нумеруются как `0.jpg`, `1.png` и так далее.

## Использование

### VK

Скачать одну или несколько статей:

```bash
swift run parse vk other \
  --nsid "<remixnsid>" \
  --sid "<remixsid>" \
  --dmgr "<remixdmgr>" \
  "https://vk.com/@example-article_1" \
  "https://vk.com/@example-article_2"
```

Если статья публичная, параметры `--nsid`, `--sid`, `--dmgr` можно не передавать.

Скачать диапазон глав по шаблону ссылки:

```bash
swift run parse vk range \
  --nsid "<remixnsid>" \
  --sid "<remixsid>" \
  --dmgr "<remixdmgr>" \
  --start 1 \
  --end 10 \
  "https://vk.com/@example-chapter_keyChapterNumberArgument"
```

Важно: в ссылке для режима `vk range` номер главы должен быть заменён на литерал `keyChapterNumberArgument`.

### Boosty

Скачать одну или несколько публикаций:

```bash
swift run parse boosty other \
  -c "%7B%22accessToken%22%3A%22...%22%2C%22refreshToken%22%3A%22...%22%2C%22expiresAt%22%3A1735689600%7D" \
  "https://boosty.to/creator/posts/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

Скачать все доступные посты по тегам:

```bash
swift run parse boosty tags \
  -c "%7B%22accessToken%22%3A%22...%22%2C%22refreshToken%22%3A%22...%22%2C%22expiresAt%22%3A1735689600%7D" \
  "https://boosty.to/creator?postsTagsIds=1,2,3"
```

Для публичных постов Boosty параметр `-c` обычно не нужен. Для закрытых постов в `-c` ожидается URL-encoded JSON с токенами, из которого используется `accessToken`.

Минимальный формат:

```json
{
  "accessToken": "token",
  "refreshToken": "refresh",
  "expiresAt": 1735689600
}
```

## Как устроен результат

### VK

- для одиночной статьи создаётся отдельная папка с изображениями;
- для диапазона глав создаётся общая папка, внутри которой появляются подпапки `1`, `2`, `3` и так далее.

### Boosty

- для одиночного поста создаётся папка с названием поста;
- для загрузки по тегам создаётся папка с названием тега или набора тегов;
- внутри неё создаются подпапки по названиям постов.

## Ошибки, которые стоит ожидать

CLI может завершиться ошибкой в таких случаях:

- ссылка невалидна или не поддерживается;
- в статье или посте не найдено ни одного изображения;
- истекли данные авторизации;
- для `vk range` указано `end < start`;
- у поста Boosty нет доступа для текущего токена.

## Структура проекта

```text
Sources/
  Common/        Общие модели, ошибки и утилиты
  Parser/        Базовая логика загрузки и сохранения файлов
  VKParser/      Разбор HTML и вложений VK
  BoostyParser/  Работа с API Boosty
  parse/         CLI-команды на swift-argument-parser
Tests/
  ParserTests/   Тестовый таргет
```

## Разработка

Запуск тестов:

```bash
swift test
```

Подключение библиотек в другой Swift Package:

```swift
.product(name: "VKParser", package: "ArticleParser")
.product(name: "BoostyParser", package: "ArticleParser")
```
