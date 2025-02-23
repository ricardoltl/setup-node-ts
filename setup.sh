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
mkdir -p src/routes src/controllers src/middlewares src/factory


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
  "exec": "ts-node src/server.ts"
}
EOL

# Criando middleware de erro global
cat <<EOL > src/middlewares/errorHandler.ts
import { Request, Response, NextFunction } from 'express';

interface ErrorResponse {
  status?: number;
  message?: string;
}

export class ErrorHandler {
  public handle(
    err: ErrorResponse,
    _req: Request,
    res: Response,
    _next: NextFunction,
  ): void {
    const status = err.status || 500;
    const message = err.message || 'Erro interno do servidor';
    res.status(status).json({ error: message });
  }
}
EOL

# Criando controller básico
cat <<EOL > src/controllers/home.controller.ts
import { Request, Response } from 'express';

class HomeController {
  public index = (_req: Request, res: Response): void => {
    res.json({ message: 'API funcionando!' });
  };
}

export default new HomeController();
EOL

# Criando teste controller
cat <<EOL > src/controllers/home.controller.test.ts
import request from 'supertest';
import express from 'express';
import HomeController from './home.controller';

describe('homeController', () => {
  let app: express.Express;

  beforeAll(() => {
    app = express();
    app.get('/', HomeController.index);
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
import HomeController from '../controllers/home.controller';

class HomeRoutes {
  public router: Router;

  constructor() {
    this.router = Router();
    this.initializeRoutes();
  }

  private initializeRoutes(): void {
    this.router.get('/', HomeController.index);
  }
}

export default new HomeRoutes().router;
EOL

cat <<EOL > src/routes/index.ts
import { Router } from 'express';
import homeRouter from './home.routes';

class Routes {
  public router: Router;

  constructor() {
    this.router = Router();
    this.initializeRoutes();
  }

  private initializeRoutes(): void {
    this.router.use('/', homeRouter);
  }
}

export default new Routes().router;
EOL

# Criando servidor Express
cat <<EOL > src/app.ts
import express, { Application } from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import routes from './routes';
import { ErrorHandler } from './middlewares/errorHandler';

dotenv.config();

export class App {
  public app: Application;
  private port: number | string;

  constructor(port?: number | string) {
    this.app = express();
    this.port = port || process.env.PORT || 3000;

    this.middlewares();
    this.routes();
    this.errorHandling();
  }

  private middlewares(): void {
    this.app.use(cors());
    this.app.use(express.json());
  }

  private routes(): void {
    this.app.use('/api', routes);
  }

  private errorHandling(): void {
    this.app.use(new ErrorHandler().handle);
  }

  public execute(): void {
    this.app.listen(this.port, () => {
      console.log('Server is running on port', this.port);
    });
  }
}
EOL

cat <<EOL > src/factory/genericFactory.ts
export class GenericFactory {
  public static createInstance<T>(
    ctor: new (...args: any[]) => T,
    ...args: any[]
  ): T {
    return new ctor(...args);
  }
}
EOL

cat <<EOL > src/server.ts
import { GenericFactory } from './factory/genericFactory';
import { App } from './app';

const appInstance = GenericFactory.createInstance(App);

appInstance.execute();
EOL

# Configurando scripts no package.json
npx json -I -f package.json -e '
  this.scripts = {
    "dev": "nodemon",
    "build": "tsc",
    "start": "tsc && node dist/server.js",
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
