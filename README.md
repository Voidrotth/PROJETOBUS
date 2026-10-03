# PROJETOBUS

## Backend

```bash
cd backend
cp .env.example .env
npm install
npm run criar-usuario -- SEMOB "SUA_SENHA" "Administrador" admin
npm run dev
```

## Frontend

Compile o painel; o backend passa a servi-lo em http://localhost:3000:

```bash
cd frontend
flutter pub get
flutter build web
```

Para desenvolver com recarga automática:

```bash
flutter run -d chrome --dart-define=API_URL=http://localhost:3000/api
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
