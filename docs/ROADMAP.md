# Roadmap

## 1.0 — Первый стабильный релиз

Цель 1.0 — не расширять продукт, а выпустить надёжный основной цикл:

```text
方向 -> Task -> Flow -> focused time -> progress -> statistics
```

### Реализовано

- [x] Общий SwiftData domain и private CloudKit store для macOS и iOS.
- [x] Основной macOS-продукт: Flow, Tasks, History, Directions и Statistics.
- [x] Flow-first iPhone-приложение с Tasks, History, Directions, Statistics и
  Settings.
- [x] Базовый Apple Watch companion.
- [x] Live Activity, Dynamic Island и Home Screen widgets.
- [x] Точная история Flow, переключения Tasks, перерывов и Flow series.
- [x] Пересчёт Task/Direction progress после создания, изменения и удаления
  истории.
- [x] Японская, английская и русская локализации.
- [x] Настройки темы, языка, недели, формата времени и границы нового дня.

### Release gate

Все пункты ниже обязательны перед публикацией 1.0:

- [ ] Провести минимум недельный daily-use burn-in без потери или дублирования
  Tasks, Habits, Flow segments, breaks и completion progress.
- [ ] Пройти матрицу реальных устройств: signed macOS + физический iPhone +
  Apple Watch; проверить запуск, pause/resume, break, восстановление после
  force-quit/reboot и принятие активного Flow с другого устройства.
- [ ] Проверить CloudKit conflict/reconciliation: одновременное изменение на
  двух устройствах, offline -> online, удаление/редактирование истории и
  отсутствие дубликатов Habits.
- [ ] Проверить миграцию копии текущей пользовательской SwiftData базы на
  release build без очистки store.
- [ ] Завершить целевые unit-тесты для timer restoration, history mutation,
  progress reconciliation, Habit materialization и CloudKit runtime revision;
  устранить воспроизводимые crashes и UI freezes.
- [ ] Проверить Live Activity, Dynamic Island, widgets и Watch на release build,
  включая системное завершение extension и временно недоступный App Group.
- [ ] Завершить проверку `ja`, `en`, `ru`: обрезание текста, Dynamic Type,
  VoiceOver labels, светлая/тёмная тема и узкие размеры окон/экранов.
- [ ] Добавить и проверить `PrivacyInfo.xcprivacy`, App Store privacy answers,
  privacy policy/support URL и описание использования iCloud.
- [ ] Развернуть проверенную CloudKit Development schema в Production и
  подтвердить чистую установку против Production environment.
- [ ] Установить app/extension/watch версии `1.0`, согласованные build numbers,
  Release signing, icons и архив без validation errors.
- [ ] Провести закрытый TestFlight/внешний smoke test и только после него
  отправлять App Store build.

### Не блокирует 1.0

- Экспорт CSV.
- Дополнительная визуальная полировка, не мешающая основному сценарию.
- Расширение быстрого ввода Tasks.
- Непотоковый непрерывный timeline.
- Новые награды, AI и внешние connectors.

## После 1.0

- Экспорт данных в CSV.
- Более подробная iPhone/Watch Statistics.
- Дальнейшее улучшение quick Task composer.
- Более продуманная система наград для `ナイス`.

## 2.0 — Server Transport и Connectors

- [ ] Добавить опциональный serverless APNs backend:
  `API Gateway -> Lambda -> EventBridge Scheduler -> APNs`.
- [ ] Регистрировать и обновлять ActivityKit push tokens без хранения Apple
  `.p8`-ключа в приложении.
- [ ] Обновлять Live Activity через APNs в момент перехода через `00:00`, чтобы
  полностью приостановленный iPhone надёжно показывал overtime `+MM:SS`.
- [ ] Добавить серверное напоминание о Flow/перерыве, который продолжается
  больше часа.
- [ ] Добавить retry/idempotency, удаление одноразовых schedules, минимальные
  CloudWatch logs и AWS Budget alerts.
- [ ] Сохранить локальный timer и CloudKit как source of truth: отсутствие
  backend или сети не должно мешать запуску и сохранению Flow.
- [ ] Добавить Connectors: Toggl, Strava, Jira и другие
  OAuth/webhook-интеграции.

## После 2.0

- AI-сводки.
- Pets.
