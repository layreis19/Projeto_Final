-- ============================================================
-- FEMME / BLOOMBOOK — SCRIPT DE CRIAÇÃO DA BASE DE DADOS
-- Motor: MySQL 8.x
-- Gerado a partir do diagrama ER (femme_er_atualizado.html)
-- ============================================================

CREATE DATABASE IF NOT EXISTS femme
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE femme;

SET FOREIGN_KEY_CHECKS = 0;

-- ------------------------------------------------------------
-- CATEGORIAS
-- ------------------------------------------------------------
DROP TABLE IF EXISTS categorias;
CREATE TABLE categorias (
  id    INT AUTO_INCREMENT PRIMARY KEY,
  nome  VARCHAR(100) NOT NULL UNIQUE
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- UTILIZADORES
-- ------------------------------------------------------------
DROP TABLE IF EXISTS utilizadores;
CREATE TABLE utilizadores (
  id             INT AUTO_INCREMENT PRIMARY KEY,
  nome           VARCHAR(150) NOT NULL,
  email          VARCHAR(150) NOT NULL UNIQUE,
  password_hash  VARCHAR(255) NULL,          -- NULL quando o utilizador só usa login social
  tipo           ENUM('cliente','profissional','admin') NOT NULL,
  estado         ENUM('ativo','desativado') NOT NULL DEFAULT 'ativo',
  criado_em      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  atualizado_em  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- LOGIN_SOCIAL  (utilizador 1--N login_social)
-- ------------------------------------------------------------
DROP TABLE IF EXISTS login_social;
CREATE TABLE login_social (
  id               INT AUTO_INCREMENT PRIMARY KEY,
  utilizador_id    INT NOT NULL,
  provider         ENUM('google','facebook','apple') NOT NULL,
  provider_user_id VARCHAR(255) NOT NULL,
  criado_em        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_login_social_utilizador
    FOREIGN KEY (utilizador_id) REFERENCES utilizadores(id) ON DELETE CASCADE,
  UNIQUE KEY uq_provider_user (provider, provider_user_id)
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- PROFISSIONAIS  (utilizador é_um profissional; categoria classifica profissional)
-- ------------------------------------------------------------
DROP TABLE IF EXISTS profissionais;
CREATE TABLE profissionais (
  id               INT AUTO_INCREMENT PRIMARY KEY,
  utilizador_id    INT NOT NULL UNIQUE,      -- 1-para-1 com utilizadores (tipo = 'profissional')
  categoria_id     INT NOT NULL,
  nome_negocio     VARCHAR(150) NOT NULL,
  descricao        TEXT NULL,
  localizacao      VARCHAR(150) NULL,
  estado_aprovacao ENUM('pendente','aprovado','rejeitado') NOT NULL DEFAULT 'pendente',
  criado_em        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_profissionais_utilizador
    FOREIGN KEY (utilizador_id) REFERENCES utilizadores(id) ON DELETE CASCADE,
  CONSTRAINT fk_profissionais_categoria
    FOREIGN KEY (categoria_id) REFERENCES categorias(id) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- Documentos de aprovação (identificação + comprovativo de atividade) — necessário
-- porque o frontend (registo.html / pagina.html) já faz upload multipart para isto.
DROP TABLE IF EXISTS profissional_documentos;
CREATE TABLE profissional_documentos (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  profissional_id INT NOT NULL,
  tipo            ENUM('identificacao','comprovativo_atividade') NOT NULL,
  caminho_ficheiro VARCHAR(255) NOT NULL,
  enviado_em      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_docs_profissional
    FOREIGN KEY (profissional_id) REFERENCES profissionais(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- NOTIFICACOES  (utilizador recebe notificações)
-- ------------------------------------------------------------
DROP TABLE IF EXISTS notificacoes;
CREATE TABLE notificacoes (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  utilizador_id INT NOT NULL,
  tipo          ENUM('marcacao','mensagem','avaliacao','sistema') NOT NULL,
  mensagem      VARCHAR(255) NULL,
  lida          BOOLEAN NOT NULL DEFAULT FALSE,
  criado_em     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_notificacoes_utilizador
    FOREIGN KEY (utilizador_id) REFERENCES utilizadores(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- DISPONIBILIDADES  (profissional define disponibilidade semanal)
-- ------------------------------------------------------------
DROP TABLE IF EXISTS disponibilidades;
CREATE TABLE disponibilidades (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  profissional_id INT NOT NULL,
  dia_semana      TINYINT NOT NULL CHECK (dia_semana BETWEEN 0 AND 6), -- 0=domingo ... 6=sábado
  hora_inicio     TIME NOT NULL,
  hora_fim        TIME NOT NULL,
  CONSTRAINT fk_disponibilidades_profissional
    FOREIGN KEY (profissional_id) REFERENCES profissionais(id) ON DELETE CASCADE,
  CONSTRAINT chk_horario CHECK (hora_fim > hora_inicio)
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- BLOQUEIOS_AGENDA  (profissional bloqueia períodos, ex.: férias)
-- ------------------------------------------------------------
DROP TABLE IF EXISTS bloqueios_agenda;
CREATE TABLE bloqueios_agenda (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  profissional_id INT NOT NULL,
  data_inicio     DATETIME NOT NULL,
  data_fim        DATETIME NOT NULL,
  motivo          VARCHAR(255) NULL,
  CONSTRAINT fk_bloqueios_profissional
    FOREIGN KEY (profissional_id) REFERENCES profissionais(id) ON DELETE CASCADE,
  CONSTRAINT chk_bloqueio_periodo CHECK (data_fim > data_inicio)
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- SERVICOS  (profissional oferece serviços)
-- ------------------------------------------------------------
DROP TABLE IF EXISTS servicos;
CREATE TABLE servicos (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  profissional_id INT NOT NULL,
  nome            VARCHAR(150) NOT NULL,
  descricao       TEXT NULL,
  preco           DECIMAL(10,2) NOT NULL,
  duracao_minutos INT NOT NULL,
  ativo           BOOLEAN NOT NULL DEFAULT TRUE,
  criado_em       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_servicos_profissional
    FOREIGN KEY (profissional_id) REFERENCES profissionais(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- MARCACOES  (cliente marca; profissional recebe; serviço origina)
-- ------------------------------------------------------------
DROP TABLE IF EXISTS marcacoes;
CREATE TABLE marcacoes (
  id                   INT AUTO_INCREMENT PRIMARY KEY,
  cliente_id           INT NOT NULL,
  profissional_id      INT NOT NULL,
  servico_id           INT NOT NULL,
  data_hora            DATETIME NOT NULL,
  preco_no_momento     DECIMAL(10,2) NOT NULL,   -- histórico: preço à data da marcação
  duracao_no_momento   INT NOT NULL,              -- histórico: duração à data da marcação
  estado               ENUM('pendente','confirmada','recusada','cancelada','concluida')
                         NOT NULL DEFAULT 'pendente',
  criado_em            DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_marcacoes_cliente
    FOREIGN KEY (cliente_id) REFERENCES utilizadores(id) ON DELETE CASCADE,
  CONSTRAINT fk_marcacoes_profissional
    FOREIGN KEY (profissional_id) REFERENCES profissionais(id) ON DELETE CASCADE,
  CONSTRAINT fk_marcacoes_servico
    FOREIGN KEY (servico_id) REFERENCES servicos(id) ON DELETE RESTRICT,
  INDEX idx_marcacoes_profissional_data (profissional_id, data_hora),
  INDEX idx_marcacoes_cliente (cliente_id)
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- AVALIACOES  (marcação gera avaliação)
-- ------------------------------------------------------------
DROP TABLE IF EXISTS avaliacoes;
CREATE TABLE avaliacoes (
  id           INT AUTO_INCREMENT PRIMARY KEY,
  marcacao_id  INT NOT NULL UNIQUE,   -- 1 avaliação por marcação
  nota         TINYINT NOT NULL CHECK (nota BETWEEN 1 AND 5),
  comentario   TEXT NULL,
  estado       ENUM('publicada','oculta') NOT NULL DEFAULT 'publicada',
  criado_em    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_avaliacoes_marcacao
    FOREIGN KEY (marcacao_id) REFERENCES marcacoes(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- MENSAGENS  (contexto = marcação; utilizador envia/recebe)
-- ------------------------------------------------------------
DROP TABLE IF EXISTS mensagens;
CREATE TABLE mensagens (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  marcacao_id     INT NOT NULL,
  remetente_id    INT NOT NULL,
  destinatario_id INT NOT NULL,
  texto           TEXT NOT NULL,
  lida            BOOLEAN NOT NULL DEFAULT FALSE,
  enviado_em      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_mensagens_marcacao
    FOREIGN KEY (marcacao_id) REFERENCES marcacoes(id) ON DELETE CASCADE,
  CONSTRAINT fk_mensagens_remetente
    FOREIGN KEY (remetente_id) REFERENCES utilizadores(id) ON DELETE CASCADE,
  CONSTRAINT fk_mensagens_destinatario
    FOREIGN KEY (destinatario_id) REFERENCES utilizadores(id) ON DELETE CASCADE,
  INDEX idx_mensagens_marcacao (marcacao_id)
) ENGINE=InnoDB;

SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================
-- DADOS DE DEMONSTRAÇÃO
-- (mesmas contas indicadas no LEIA-ME.txt do frontend)
-- Nota: os password_hash abaixo são placeholders — substitui por hashes
-- reais gerados com bcrypt no backend antes de usar em produção.
-- ============================================================

INSERT INTO categorias (nome) VALUES
  ('Cabeleireiro'), ('Estética Facial'), ('Manicure e Pedicure'),
  ('Massagem'), ('Maquilhagem'), ('Depilação');

INSERT INTO utilizadores (nome, email, password_hash, tipo, estado) VALUES
  ('Administrador Femme', 'admin@femme.pt', '$2b$10$PLACEHOLDER_HASH_ADMIN', 'admin', 'ativo'),
  ('Inês Marques', 'ines.marques@femme.pt', '$2b$10$PLACEHOLDER_HASH_INES', 'profissional', 'ativo'),
  ('Rita Esteves', 'rita.esteves@femme.pt', '$2b$10$PLACEHOLDER_HASH_RITA', 'profissional', 'ativo'),
  ('Ana Costa', 'ana.costa@gmail.com', '$2b$10$PLACEHOLDER_HASH_ANA', 'cliente', 'ativo');

INSERT INTO profissionais (utilizador_id, categoria_id, nome_negocio, estado_aprovacao) VALUES
  ((SELECT id FROM utilizadores WHERE email='ines.marques@femme.pt'), 1, 'Inês Marques Hair Studio', 'aprovado'),
  ((SELECT id FROM utilizadores WHERE email='rita.esteves@femme.pt'), 2, 'Rita Esteves Estética', 'pendente');

INSERT INTO servicos (profissional_id, nome, preco, duracao_minutos, ativo) VALUES
  ((SELECT id FROM profissionais WHERE nome_negocio='Inês Marques Hair Studio'), 'Corte + Escova', 25.00, 45, TRUE),
  ((SELECT id FROM profissionais WHERE nome_negocio='Inês Marques Hair Studio'), 'Coloração', 60.00, 120, TRUE);

INSERT INTO disponibilidades (profissional_id, dia_semana, hora_inicio, hora_fim) VALUES
  ((SELECT id FROM profissionais WHERE nome_negocio='Inês Marques Hair Studio'), 1, '09:00:00', '18:00:00'),
  ((SELECT id FROM profissionais WHERE nome_negocio='Inês Marques Hair Studio'), 2, '09:00:00', '18:00:00');
