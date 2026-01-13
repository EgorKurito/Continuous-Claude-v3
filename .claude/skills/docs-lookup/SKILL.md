---
name: docs-lookup
description: Lookup current library documentation via Context7 MCP
allowed-tools: [mcp__context7__resolve-library-id, mcp__context7__get-library-docs]
keywords: [docs, documentation, api reference, library docs, current version]
---

# Docs Lookup - Context7 Documentation / Поиск документации

Fetch current, version-specific documentation for any library via Context7 MCP.
Получить актуальную документацию по любой библиотеке через Context7 MCP.

## Usage / Использование

```
/docs-lookup <library> [topic]
/найди-доки <библиотека> [тема]
/docs <library> [topic]
```

## Examples / Примеры

```bash
# Get React hooks documentation
/docs-lookup react hooks

# Get Next.js server actions docs
/docs-lookup next.js server actions

# Get Prisma ORM setup guide
/docs-lookup prisma getting started

# Получить документацию по React hooks
/найди-доки react hooks
```

## Question Flow (No Arguments) / Поток вопросов (без аргументов)

If the user types just `/docs-lookup` with no arguments, guide them through this question flow.
Если пользователь вводит `/docs-lookup` без аргументов, проведите его через этот поток вопросов.

### Phase 1: Library Selection / Выбор библиотеки

```yaml
question: "Which library do you need docs for? / Для какой библиотеки нужна документация?"
header: "Library / Библиотека"
options:
  - label: "React"
    description: "React core library / Основная библиотека React"
  - label: "Next.js"
    description: "Full-stack React framework / Фреймворк для React"
  - label: "Prisma"
    description: "TypeScript ORM / TypeScript ORM"
  - label: "Other / Другая"
    description: "I'll specify the library name / Я укажу название"
```

**If "Other":** Ask for library name in free text.

### Phase 2: Topic Selection / Выбор темы

```yaml
question: "What topic within {library}? / Какая тема в {library}?"
header: "Topic / Тема"
options:
  - label: "Getting started / Начало работы"
    description: "Installation and setup / Установка и настройка"
  - label: "API reference / Справка API"
    description: "Complete API docs / Полная документация API"
  - label: "Specific feature / Конкретная функция"
    description: "I'll specify the feature / Я укажу функцию"
```

**If "Specific feature":** Ask for feature name in free text.

### Phase 3: Token Limit / Лимит токенов

```yaml
question: "How much documentation do you need? / Сколько документации нужно?"
header: "Size / Размер"
options:
  - label: "Quick overview (2000 tokens) / Краткий обзор"
    description: "Concise summary / Краткое описание"
  - label: "Standard (5000 tokens) (Recommended) / Стандарт (Рекомендуется)"
    description: "Balanced coverage / Сбалансированный охват"
  - label: "Comprehensive (10000 tokens) / Полный"
    description: "Detailed documentation / Детальная документация"
```

## Implementation / Реализация

When executing this skill:

### Step 1: Resolve Library ID

```
Call: mcp__context7__resolve-library-id
Input: { "libraryName": "<user-specified-library>" }
Output: Context7 library ID (e.g., "/facebook/react")
```

### Step 2: Fetch Documentation

```
Call: mcp__context7__get-library-docs
Input: {
  "context7CompatibleLibraryID": "<resolved-id>",
  "topic": "<user-specified-topic>",
  "tokens": <selected-token-limit>
}
Output: Current documentation and code examples
```

### Step 3: Present Results

Format the documentation in a readable way:

```markdown
## {Library} Documentation: {Topic}

{Documentation content from Context7}

---
Source: Context7 (fetched {timestamp})
Library ID: {context7-id}
```

## Popular Libraries / Популярные библиотеки

| Library | Context7 ID | Common Topics |
|---------|-------------|---------------|
| React | /facebook/react | hooks, components, context |
| Next.js | /vercel/next.js | routing, server actions, app router |
| Prisma | /prisma/prisma | schema, queries, migrations |
| TypeScript | /microsoft/TypeScript | types, generics, decorators |
| Tailwind | /tailwindlabs/tailwindcss | utilities, configuration |
| Express | /expressjs/express | routing, middleware |
| Vue | /vuejs/vue | composition API, reactivity |

## Error Handling / Обработка ошибок

If Context7 returns no results:
1. Check library name spelling
2. Try broader topic (e.g., "routing" instead of "dynamic routing")
3. Library may not be indexed - suggest web search

## Notes / Примечания

- Context7 fetches **current** documentation, not LLM training data
- Token limit affects documentation depth (more tokens = more detail)
- Some libraries have version-specific IDs (e.g., /vercel/next.js/v15.0.0)

## Related Skills / Связанные навыки

| Skill | When to Use / Когда использовать |
|-------|----------------------------------|
| **nia-docs** | Alternative doc search via Nia MCP |
| **perplexity-search** | Web search for docs not in Context7 |
| **research-external** | Broader external research workflow |
