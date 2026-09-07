# DIMAX Final Go / No-Go Package

<!-- dimax-release-index:v1 -->

Этот файл является стабильным индексом релизного решения. Динамические проценты,
счётчики тестов и состояние окружения намеренно не дублируются: их авторитетный
источник формируется автоматическими проверками.

## Авторитетный статус

- Текущее решение: `artifacts/release/release-status-latest.md`.
- Полный handoff: `artifacts/release/release-handoff-latest.md`.
- Безопасность исходного набора: `artifacts/release/source-readiness-latest.md`.
- Группировка изменений: `artifacts/release/change-report-latest.md`.
- Аудит зависимостей: `artifacts/release/dependency-audit-latest.md`.
- Android QA: `artifacts/release/android-qa-report-latest.md`.
- Бизнес-smoke: `artifacts/release/business-smoke-latest.md`.

Обновить статус:

```powershell
.\workspace.cmd release-status
.\workspace.cmd release-handoff
.\workspace.cmd source-readiness
.\workspace.cmd dependency-audit
```

## Правило решения

- Code gate пройден только тогда, когда автоматический release-status не показывает
  `CODE NO-GO`.
- Release source готов только при чистых рабочих деревьях `workspace`, `backend`,
  `admin` и `mobile`, проверяемых commit SHA и синхронизации с upstream.
- Production остаётся `NO-GO`, пока не валидированы реальные backend, admin и
  mobile env, не предоставлен Android release keystore и не пройден post-deploy
  smoke на целевой инфраструктуре.
- Production можно объявить `GO` только после выполнения `POST_DEPLOY_SMOKE.md`.

## Реальные production-входы

- PostgreSQL URL с TLS;
- HTTPS-домены API и admin;
- JWT и integration secrets;
- S3/MinIO endpoint, bucket и credentials;
- initial owner credentials;
- точный backend image по sha256 digest или source-SHA tag;
- mobile HTTPS API URL;
- Android release keystore и четыре переменные `DIMAX_ANDROID_*`.

Фиктивные значения не считаются готовностью и должны отклоняться production
валидаторами.
