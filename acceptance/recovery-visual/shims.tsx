import React from 'react';
const scope = new URLSearchParams(location.search).get('role') || 'OWNER';
const session = { role: scope === 'INSTALLER' ? 'INSTALLER' : 'ADMIN', admin_scope: scope,
  company_id: '00000000-0000-4000-8000-000000000001', user_id: '00000000-0000-4000-8000-000000000010' };
export const useAuthSession = () => session;
export const usePathname = () => '/operations/recovery';
const router = { push: () => {}, replace: () => {}, refresh: () => {} };
export const useRouter = () => router;
export default function Link({ children, href, prefetch, ...props }: any) {
  return <a {...props} href={href} onClick={event => event.preventDefault()}>{children}</a>;
}
