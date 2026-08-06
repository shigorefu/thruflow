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
- [x] Знакомство из семи центральных карточек поверх настоящих экранов
  macOS/iPhone/iPad: автоматическая навигация между разделами, финальная схема
  `方向 → タスク → Flow → 履歴・統計 → 次の一歩`, отдельные preview-схемы и повторный
  запуск из Settings без подсветки элементов и создания тестовых данных.
- [x] Ненавязчивый системный запрос оценки после подтверждённого использования,
  GitHub и добровольные StoreKit tips: кофе ¥100 / рамэн ¥500.
- [x] Настраиваемый CSV-экспорт статистики.
- [x] Безопасное удаление всей Flow-истории из Settings с сохранением Tasks и
  `方向`, сбросом вычисляемого прогресса и синхронизацией через private CloudKit.

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
- [x] Добавить и проверить `PrivacyInfo.xcprivacy` для приложения, Watch и
  widget/Live Activity extension.
- [ ] Заполнить App Store privacy answers, privacy policy/support URL и
  описание использования private iCloud sync.
- [ ] Создать в App Store Connect consumable IAP с идентификаторами
  `com.shigorefu.thruflow.tip.coffee` и
  `com.shigorefu.thruflow.tip.ramen`, назначить японские цены ¥100/¥500,
  локализации и review screenshot; после создания приложения задать
  `THRUFLOW_APP_STORE_ID` для прямой ссылки на отзыв.
- [ ] Развернуть проверенную CloudKit Development schema в Production и
  подтвердить чистую установку против Production environment.
- [ ] Установить app/extension/watch версии `1.0`, согласованные build numbers,
  Release signing, icons и архив без validation errors.
- [ ] Провести закрытый TestFlight/внешний smoke test и только после него
  отправлять App Store build.

### Не блокирует 1.0

- Дополнительная визуальная полировка, не мешающая основному сценарию.
- Расширение быстрого ввода Tasks.
- Непотоковый непрерывный timeline.
- Новые награды, AI и внешние connectors.

## 1.1 — Осознанное незаполненное время

Эта функция не блокирует TestFlight и релиз 1.0. В 1.0 `履歴` продолжает
показывать незаполненные промежутки и позволяет заполнять их вручную. После
проверки основного цикла на реальных пользователях приложение сможет мягко
предлагать классифицировать длинные промежутки вне Flow.

- [ ] Перед реализацией подтвердить по TestFlight-обратной связи полезный порог;
  начальное предположение — `60–90` минут без записи.
- [ ] Показывать необязательное предложение при открытии приложения или
  `履歴`, а не прерывающий popup и не автоматическое уведомление.
- [ ] Формулировать вопрос нейтрально: «Чем было занято это время?», не
  предполагая, что пользователь ничего не делал.
- [ ] Предлагать быстрые варианты `睡眠`, `休憩`, `食事`, `移動`, `その他` и
  `スキップ`.
- [ ] Позволить пропустить вопрос, отключить предложения на текущий день или
  полностью выключить функцию.
- [ ] Не создавать несколько последовательных вопросов за ночь или длинный
  период отсутствия; объединять их в спокойный обзор незаполненного времени.
- [ ] Хранить время вне Flow отдельно от Task/Direction progress: такие записи
  не начисляют Blocks и не считаются сфокусированным временем.

## Другие задачи после 1.0

- Более подробная watchOS Statistics.
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
