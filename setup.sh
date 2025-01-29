#!/bin/bash

# Ativa modo de saída imediata em caso de erro
set -e

# Verifica se o usuário passou um nome para o projeto
if [ -z "$1" ]; then
  echo "Uso: ./setup.sh nome-do-projeto"
  exit 1
fi

PROJECT_NAME=$1

# Verifica se já existe uma pasta com esse nome
if [ -d "$PROJECT_NAME" ]; then
  echo "Erro: A pasta '$PROJECT_NAME' já existe."
  exit 1
fi

# Verifica se os comandos necessários estão instalados
for cmd in npm npx git docker; do
  if ! command -v $cmd &> /dev/null; then
    echo "Erro: '$cmd' não está instalado. Instale e tente novamente."
    exit 1
  fi
done

# Criando a pasta do projeto
mkdir "$PROJECT_NAME" && cd "$PROJECT_NAME"

# Inicializando o projeto Node.js
npm init -y

# Instalando dependências principais e dev
npm install express cors dotenv
npm install --save-dev typescript ts-node nodemon @types/node @types/express @types/cors \
  @typescript-eslint/parser @typescript-eslint/eslint-plugin eslint \
  eslint-config-prettier eslint-plugin-prettier eslint-plugin-jest prettier husky jest \
  ts-jest @types/jest supertest @types/supertest


# Criando estrutura de pastas
mkdir -p src/routes src/controllers src/middlewares

# Criando arquivos básicos
touch src/index.ts src/routes/index.ts src/controllers/homeController.ts src/middlewares/errorHandler.ts

# Criando .gitignore antes do Git
cat <<EOL > .gitignore
node_modules
dist
.env
coverage
EOL

# Configurando TypeScript
npx tsc --init --rootDir src --outDir dist --esModuleInterop true --resolveJsonModule true --strict true

# Configurando ESLint
cat <<EOL > eslint.config.mjs
import tseslint from '@typescript-eslint/eslint-plugin';
import tsparser from '@typescript-eslint/parser';
import prettier from 'eslint-plugin-prettier';
import jest from 'eslint-plugin-jest';

export default [
  {
    files: ['**/*.ts', '**/*.tsx'],
    languageOptions: {
      parser: tsparser,
      parserOptions: {
        ecmaVersion: 'latest',
        sourceType: 'module',
        project: './tsconfig.json',
      },
    },
    plugins: {
      '@typescript-eslint': tseslint,
      prettier,
      jest,
    },
    rules: {
      'prettier/prettier': 'error',
      'no-useless-return': 'error',
      '@typescript-eslint/explicit-function-return-type': 'warn',
      'jest/no-disabled-tests': 'warn',
      'jest/no-focused-tests': 'error',
      'jest/no-identical-title': 'error',
      'jest/prefer-to-have-length': 'warn',
      'jest/valid-expect': 'error',
    },
  },
];
EOL

# Configuração do Prettier
cat <<EOL > .prettierrc
{
  "singleQuote": true,
  "trailingComma": "all",
  "semi": true,
  "tabWidth": 2
}
EOL

# Configuração do Jest
cat <<EOL > jest.config.mjs
export default {
  preset: 'ts-jest',
  testEnvironment: 'node',
};
EOL

# Criando Dockerfile
cat <<EOL > Dockerfile
FROM node:20.18.0
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 3000
CMD ["npm", "run", "dev"]
EOL

# Criando docker-compose.yml
cat <<EOL > docker-compose.yml
services:
  app:
    build: .
    ports:
      - '3000:3000'
    volumes:
      - .:/app
      - /app/node_modules
    environment:
      - NODE_ENV=development
    restart: unless-stopped
    command: npm run dev
EOL

# Configurando nodemon
cat <<EOL > nodemon.json
{
  "watch": ["src"],
  "ext": "ts",
  "exec": "ts-node src/index.ts"
}
EOL

# Criando middleware de erro global
cat <<EOL > src/middlewares/errorHandler.ts
import { Request, Response, NextFunction } from 'express';

interface ErrorResponse {
  status: number;
  message: string;
}

export function errorHandler(
  err: ErrorResponse,
  _req: Request,
  res: Response,
  _next: NextFunction,
): void {
  const status = err.status || 500;
  const message = err.message || 'Erro interno do servidor';
  res.status(status).json({ error: message });
}
EOL

# Criando controller básico
cat <<EOL > src/controllers/homeController.ts
import { Request, Response } from 'express';

export function homeController(req: Request, res: Response): void {
  res.json({ message: 'API funcionando!' });
}
EOL

# Criando teste controller
cat <<EOL > src/controllers/homeController.test.ts;
import request from 'supertest';
import express from 'express';
import { homeController } from './homeController';

describe('homeController', () => {
  let app: express.Express;

  beforeAll(() => {
    app = express();
    app.get('/', homeController);
  });

  it('Deve retornar status 200 e mensagem correta', async () => {
    const response = await request(app).get('/');

    expect(response.status).toBe(200);
    expect(response.body).toEqual({ message: 'API funcionando!' });
  });
});
EOL

# Criando rotas
cat <<EOL > src/routes/home.routes.ts
import { Router } from 'express';
import { homeController } from '../controllers/homeController';

const homeRouter = Router();

homeRouter.get('/', homeController);

export default homeRouter;
EOL

cat <<EOL > src/routes/index.ts
import { Router } from 'express';
import homeRouter from './home.routes';

const router = Router();

router.use('/', homeRouter);

export default router;
EOL

# Criando servidor Express
cat <<EOL > src/index.ts
import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import routes from './routes';
import { errorHandler } from './middlewares/errorHandler';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());
app.use('/api', routes);
app.use(errorHandler);

app.listen(PORT, () => {
  console.log(\`Servidor rodando na porta \${PORT}\`);
});
EOL

# Configurando scripts no package.json
npx json -I -f package.json -e '
  this.scripts = {
    "dev": "nodemon",
    "build": "tsc",
    "start": "node dist/index.js",
    "lint": "eslint .",
    "lint:fix": "eslint . --fix",
    "format": "prettier --write \"src/**/*.{ts,tsx}\"",
    "test": "jest"
  }
'

# Inicializando repositório Git e commit inicial
git init
git add .
git commit -m "Initial commit"

# Inicializando Husky e adicionando pre-commit hook
npx husky-init && npm install

# Configurando pre-commit hook
cat <<EOL > .husky/pre-commit
#!/bin/sh
. "\$(dirname "\$0")/_/husky.sh"

npx eslint . && npm test
EOL
chmod +x .husky/pre-commit

echo "Projeto '$PROJECT_NAME' configurado com sucesso! �"
