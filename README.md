# PROJETOBUS

## Backend

```bash
cd backend
cp .env.example .env
npm install
npm run criar-usuario -- admin@semob.com "SUA_SENHA" "Administrador" admin
npm run dev
```

## Frontend

```bash
cd frontend
flutter pub get
flutter run -d chrome
```

Se o backend não estiver na porta 3000:

```bash
flutter run -d chrome --dart-define=API_URL=http://localhost:3100/api
```

## Importar relatórios da pasta dados/

```bash
cd backend
npm run importar-dados
```

## Testes

```bash
cd backend
npm test
```
