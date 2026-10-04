# Currículos

Aplicação Rails para gerenciar e personalizar currículos por vaga, com IA integrada.
O app mantém um **perfil mestre** (experiências, formação, projetos, skills, idiomas)
em múltiplos idiomas e gera currículos adaptados para cada vaga, destacando keywords
da descrição, sugerindo ajustes e produzindo resumo/carta de apresentação.

## Funcionalidades

- **Perfil mestre** em PT/EN com todas as experiências, projetos, formação, certificações, skills e idiomas.
- **Vagas**: cole a descrição da vaga e a IA extrai título, empresa, requisitos e keywords.
- **Análise de match**: compara seu perfil com a vaga, pontua compatibilidade e destaca keywords presentes/ausentes.
- **Currículo adaptado**: resumo profissional e bullets reescritos sob medida para a vaga (`ai/adapt`).
- **Carta de apresentação** e resumo gerados por IA (`ai/generate`).
- **Assistente de chat**: converse para criar vagas, ajustar o perfil e adaptar o currículo via ações estruturadas.
- **Impressão/PDF**: layout de currículo otimizado para impressão (A4/Letter), com destaque de keywords.
- **Importação de perfil**: importa currículo em PDF (LinkedIn e outros) para preencher o perfil.
- **Backup/restore**: exporta e importa todos os dados em JSON.
- **Multi-provider de IA**: Ollama (local, sem API key), OpenAI e compatíveis, Anthropic e Gemini, configurável em Settings.

## Stack

- **Rails 8.1** / Ruby 3.4
- **SQLite**: banco em arquivo, zero infraestrutura
- **Hotwire**: Turbo + Stimulus com importmap (sem build de JS)
- **Propshaft**: assets
- **pdf-reader**: importação de currículos em PDF

## Requisitos

- Ruby 3.4+
- (Opcional) [Ollama](https://ollama.com) rodando localmente para IA sem custo, ou uma API key de OpenAI/Anthropic/Gemini

## Setup

```bash
bin/setup
```

Instala as dependências, prepara o banco (com dados de exemplo na primeira vez) e
sobe o servidor em http://localhost:3000.

Para rodar depois:

```bash
bin/dev
```

## Configurando a IA

1. Acesse **Settings** na interface.
2. Escolha o provider:
   - **Ollama**: default `http://localhost:11434`, sem API key. Ex.: `qwen2.5`, `llama3.1`.
   - **OpenAI**: API key + base URL (funciona com Groq, OpenRouter, etc.).
   - **Anthropic** / **Gemini**: API key do respectivo serviço.
3. Defina o modelo e use o botão de teste para validar a conexão.

Sem provider configurado o app funciona normalmente; apenas as funcionalidades de IA ficam desabilitadas.

## Testes e checks

```bash
bin/rails test     # testes
bin/rubocop        # lint
bin/brakeman       # análise de segurança
bin/ci             # suite completa de CI
```

## Estrutura

```
app/
├── controllers/   # Jobs, Profiles, Ai, Assistant, Settings, Backups
├── models/        # Profile, Job, Experience, Education, Skill, ChatMessage, AiEdit...
├── services/      # LlmClient, AiWriter, AiMatcher, AiExtractor, Assistant,
│                  # KeywordExtractor, ResumeTailor, ProfileImporter, Backup...
├── javascript/    # Stimulus controllers (chat, autosave, highlight, print...)
└── views/         # ERB + Turbo Streams
```

## Backup

A tela de **Backup** exporta todo o banco para JSON e permite restaurar depois,
útil para migrar entre máquinas ou antes de testar algo arriscado.

## Roadmap

- **Mais funcionalidades sem IA**: expandir o que o app faz de forma determinística
  (extração de keywords, match, análise de currículo) para depender menos de LLM.
- **Sistema de agentes baseado em regras e dados**: pipeline de agentes que analisam
  o currículo com regras e dados reais (densidade de keywords, impacto de bullets,
  cobertura de requisitos, formatação/ATS) em vez de prompts genéricos.

## Licença

Uso pessoal.
