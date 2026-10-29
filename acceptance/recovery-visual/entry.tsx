import React from 'react';
import { createRoot } from 'react-dom/client';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { LanguageProvider } from '@/lib/i18n';
import OutboxRecoveryPage from '@/views/OutboxRecoveryPage';
import '@/index.css';
const params = new URLSearchParams(location.search);
localStorage.setItem('dimax_locale', params.get('lang') || 'ru');
const client = new QueryClient({ defaultOptions: { queries: { retry: false }, mutations: { retry: false } } });
function Preview() {
  return <><aside style={{ padding: '8px 16px', background: '#fff3ce', color: '#302200', font: '13px/1.5 sans-serif' }}>
    <strong>ИЗОЛИРОВАННАЯ ПРОВЕРКА UI</strong> · Синтетические данные · Backend и отправка писем не подключены.
    <form method="get" onSubmit={event => { event.preventDefault(); const values = new FormData(event.currentTarget); location.search = new URLSearchParams(values as any).toString(); }} style={{ display: 'flex', flexWrap: 'wrap', gap: 12, marginTop: 6 }}>
      <label>Роль <select name="role" defaultValue={params.get('role') || 'OWNER'}>{['OWNER', 'OPERATIONS', 'FINANCE', 'INSTALLER'].map(value => <option key={value}>{value}</option>)}</select></label>
      <label>Сценарий <select name="scenario" defaultValue={params.get('scenario') || 'normal'}>{['normal', 'conflict', 'lost-response', 'unavailable'].map(value => <option key={value}>{value}</option>)}</select></label>
      <label>Язык <select name="lang" defaultValue={params.get('lang') || 'ru'}>{['ru', 'en', 'he'].map(value => <option key={value}>{value}</option>)}</select></label>
      <button type="submit">Открыть сценарий</button>
    </form>
  </aside><QueryClientProvider client={client}><LanguageProvider><OutboxRecoveryPage /></LanguageProvider></QueryClientProvider></>;
}
createRoot(document.getElementById('root')!).render(<Preview />);
