
-- Importando os dados dos COMERCIAIS
INSERT INTO comercial (Nome, telefone, email)
SELECT DISTINCT
    Comercial_Representante,
    CONCAT(DDD_Comercial, Telefone_Comercial),
    Email_Comercial
FROM leilao_bruto
WHERE Comercial_Representante IS NOT NULL
  AND Comercial_Representante <> '0';


-- IMPORTANDO DADOS DA LOCALIZAÇÃO
INSERT INTO localizacao (Comarca, Estado, Regiao, Rua)
SELECT DISTINCT
    Comarca,
    Estado,
    Regiao,
    'A definir'
FROM leilao_bruto
WHERE Comarca IS NOT NULL
  AND Comarca <> '0';
  
-- DADOS DO JUIZ
INSERT INTO juiz (nome)
SELECT DISTINCT Juiz
FROM leilao_bruto
WHERE Juiz IS NOT NULL
  AND Juiz <> '0';

-- DIRETOR DO CARTÓRIO
INSERT INTO diretor_cartorio (Nome, ddd, telefone, email)
SELECT DISTINCT
    Diretor_Cartorio,
    DDD_Diretor,
    Telefone_Diretor,
    Email_Diretor
FROM leilao_bruto
WHERE Diretor_Cartorio IS NOT NULL
  AND Diretor_Cartorio <> '0';


-- DADOS DA PRAÇA
INSERT INTO praca (data_abertura, data_fechamento, dia_semana)
SELECT DISTINCT
    STR_TO_DATE(Data_abertura, '%d/%m/%Y'), -- CONVERTENDO PARA O FORMATO PADRÃO DO mysql
    STR_TO_DATE(Data_fechamento, '%d/%m/%Y'),
    Dia_semana
FROM leilao_bruto
WHERE Data_abertura IS NOT NULL;

-- DADOS DO LEILOEIRO
INSERT INTO leiloeiro (nome, Jucesp)
SELECT DISTINCT
    Leiloeiro,
    JUCESP
FROM leilao_bruto
WHERE Leiloeiro IS NOT NULL
  AND Leiloeiro <> '0';


-- dados do lote
TRUNCATE TABLE lote;

INSERT INTO lote (
    item_id_origem, sublote, categoria, subcategoria, Valor_inicial,
    id_arrematante, incremento, resultado, qtd_lances,
    valor_lance_final, percentual_comissao, comissao_leiloeiro
)
SELECT DISTINCT
    b.Item_ID,
    b.SubLote,
    b.Categoria,
    b.Subcategoria,
    CAST(REPLACE(b.Valor_Inicial, ',', '.') AS DECIMAL(10,2)),
    a.id_arrematante,
    b.incremento,
    b.Resultado,
    b.Quantidade_Lances,
    CAST(REPLACE(b.Valor_lance, ',', '.') AS DECIMAL(10,2)),
    CAST(REPLACE(b.percentual_comissao, '%', '') AS DECIMAL(5,2)),
    CAST(REPLACE(b.comissao_leiloeiro, ',', '.') AS DECIMAL(10,2))
FROM leilao_bruto b
LEFT JOIN arrematante a
    ON a.nome = b.Arrematante
    AND a.telefone = b.Telefone_Arrematante
    AND a.email = b.Email_Arrematante;

-- Dados do cartorio
INSERT INTO cartorio (Vara, id_Juiz, ID_local_cartorio, id_diretor, comarca, id_comercial)
SELECT DISTINCT
    b.Vara,
    j.id_Juiz,
    loc.ID_local_cartorio,
    d.id_diretor,
    b.Comarca,
    c.idComercial
FROM leilao_bruto b
LEFT JOIN juiz j ON j.nome = b.Juiz
LEFT JOIN localizacao loc ON loc.Comarca = b.Comarca AND loc.Estado = b.Estado AND loc.Regiao = b.Regiao
LEFT JOIN diretor_cartorio d ON d.Nome = b.Diretor_Cartorio AND d.telefone = b.Telefone_Diretor
LEFT JOIN comercial c ON c.Nome = b.Comercial_Representante AND c.telefone = CONCAT(b.DDD_Comercial, b.Telefone_Comercial);

-- Dados cartório
INSERT INTO processo (tipo_de_acao, Reu, Autor, id_cartorio)
SELECT DISTINCT
    b.Tipo_de_Acao,
    b.Reu,
    b.Autor,
    ct.Id_cartorio
FROM leilao_bruto b
LEFT JOIN cartorio ct 
    ON ct.Vara = b.Vara 
    AND ct.comarca = b.Comarca;

-- DADOS DO LEILÃO
INSERT INTO leilao (Id_praca, id_lote, id_processo, id_leiloeiro)
SELECT DISTINCT
    p.Id_praca,
    lt.id_lote,
    pr.id_processo,
    le.id_leiloeiro
FROM leilao_bruto b
LEFT JOIN praca p 
    ON p.numero_praca = b.Praca
    AND p.data_abertura = STR_TO_DATE(b.Data_abertura, '%d/%m/%Y')
    AND p.data_fechamento = STR_TO_DATE(b.Data_fechamento, '%d/%m/%Y')
    AND p.dia_semana = b.Dia_semana
LEFT JOIN lote lt 
    ON lt.item_id_origem = b.Item_ID
LEFT JOIN processo pr 
    ON pr.numero_processo_origem = b.Processo
LEFT JOIN leiloeiro le 
    ON le.nome = b.Leiloeiro;

-- DADOS DO ARREMATANTE
INSERT INTO arrematante (nome, ddd, telefone, email, endereco)
SELECT DISTINCT
    Arrematante,
    DDD_Arrematante,
    Telefone_Arrematante,
    Email_Arrematante,
    'A definir'
FROM leilao_bruto
WHERE Arrematante IS NOT NULL
  AND Arrematante <> '0'
  AND DDD_Arrematante REGEXP '^[0-9]+$';
  