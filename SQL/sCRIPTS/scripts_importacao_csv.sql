-- Entidades PAI que não dependem de outra

CREATE TABLE comercial (
    idComercial INT AUTO_INCREMENT PRIMARY KEY,
    Nome VARCHAR(45),
    telefone VARCHAR(45),
    email VARCHAR(45)
);

CREATE TABLE localizacao (
    ID_local_cartorio INT AUTO_INCREMENT PRIMARY KEY,
    Comarca VARCHAR(45),
    Estado VARCHAR(45),
    Regiao VARCHAR(45),
    Rua VARCHAR(45)
);

CREATE TABLE juiz (
    id_Juiz INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(45)
);

CREATE TABLE diretor_cartorio (
    id_diretor INT AUTO_INCREMENT PRIMARY KEY,
    Nome VARCHAR(45),
    ddd INT,
    telefone VARCHAR(45),
    email VARCHAR(45)
);

CREATE TABLE praca (
    Id_praca INT AUTO_INCREMENT PRIMARY KEY,
    data_abertura DATE,
    data_fechamento DATE,
    dia_semana VARCHAR(45)
);

CREATE TABLE leiloeiro (
    id_leiloeiro INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(45),
    Jucesp INT
);

CREATE TABLE arrematante (
    id_arrematante INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(45),
    ddd INT,
    telefone VARCHAR(45),
    email VARCHAR(45),
    endereco VARCHAR(45)
);

-- entidades FIlhas, que dependem de outra entidade
CREATE TABLE lote (
    id_lote INT AUTO_INCREMENT PRIMARY KEY,
    sublote INT,
    categoria VARCHAR(45),
    subcategoria VARCHAR(45),
    Valor_inicial FLOAT,
    id_arrematante INT,        -- FK futura -> arrematante
    incremento INT,
    resultado VARCHAR(45),
    qtd_lances INT,
    valor_lance_final FLOAT,
    percentual_comissao INT,
    comissao_leiloeiro FLOAT
);

CREATE TABLE cartorio (
    Id_cartorio INT AUTO_INCREMENT PRIMARY KEY,
    Vara INT,
    id_Juiz INT,                -- FK futura -> juiz
    ID_local_cartorio INT,      -- FK futura -> localizacao
    id_diretor INT,             -- FK futura -> diretor_cartorio
    comarca VARCHAR(45),
    id_comercial INT            -- FK futura -> comercial
);

CREATE TABLE processo (
    id_processo INT AUTO_INCREMENT PRIMARY KEY,
    tipo_de_acao VARCHAR(45),
    Reu VARCHAR(45),
    Autor VARCHAR(45),
    id_cartorio INT              -- FK futura -> cartorio
);

CREATE TABLE leilao (
    idLEILAO INT AUTO_INCREMENT PRIMARY KEY,
    Id_praca INT,        -- FK futura -> praca
    id_lote INT,         -- FK futura -> lote
    id_processo INT,     -- FK futura -> processo
    id_leiloeiro INT     -- FK futura -> leiloeiro
);
