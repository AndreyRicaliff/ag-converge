export const config = {
  matcher: ['/admin', '/admin.html', '/portaria', '/portaria.html'],
};

const REALM = 'AG Converge — Restrito';

// Credenciais da camada HTTP (diferente da senha interna do admin)
// Usuário: ag  |  Senha: converge@2026
const VALID = 'ag:converge@2026';

export default function middleware(request) {
  const auth = request.headers.get('authorization') ?? '';

  if (auth.startsWith('Basic ')) {
    const decoded = atob(auth.slice(6));
    if (decoded === VALID) {
      return new Response(null, { status: 200 });
    }
  }

  return new Response('Acesso restrito.', {
    status: 401,
    headers: {
      'WWW-Authenticate': `Basic realm="${REALM}"`,
      'Content-Type': 'text/plain; charset=utf-8',
    },
  });
}
