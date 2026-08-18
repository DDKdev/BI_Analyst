-- 01_investigacao_lote_id_lote.sql
-- Investigação das colunas Lote, ID_Lote, SubLote (não usadas até então)
-- Objetivo: entender qual coluna identifica o "mesmo bem físico" entre praças

SELECT Processo, Lote, ID_Lote, SubLote, Praca, Data_abertura, Item_ID
FROM leilao_bruto
WHERE Processo = '000009080' AND Lote = 1
ORDER BY Praca, SubLote;


-- 02_diagnostico_falso_positivo.sql
-- ATENÇÃO: esta query contém um erro proposital documentado (comparação de
-- datas como TEXTO, não DATE) — mantida aqui como registro do erro e do
-- porquê ele gerou falso positivo. Ver 03 para a versão corrigida.

SELECT DISTINCT
    b1.Processo, b1.Lote,
    b1.Praca AS praca_x, b1.Data_abertura AS data_x,
    b2.Praca AS praca_y, b2.Data_abertura AS data_y
FROM leilao_bruto b1
JOIN leilao_bruto b2
    ON b1.Processo = b2.Processo
    AND b1.Lote = b2.Lote
    AND b1.Praca < b2.Praca
    AND b1.Data_abertura > b2.Data_abertura;  -- ERRO: comparação de texto


-- 03_diagnostico_corrigido_str_to_date.sql
-- Versão corrigida, com STR_TO_DATE para comparação cronológica real

SELECT DISTINCT
    b1.Processo, b1.Lote,
    b1.Praca AS praca_x, b1.Data_abertura AS data_x,
    b2.Praca AS praca_y, b2.Data_abertura AS data_y
FROM leilao_bruto b1
JOIN leilao_bruto b2
    ON b1.Processo = b2.Processo
    AND b1.Lote = b2.Lote
    AND b1.Praca < b2.Praca
    AND STR_TO_DATE(b1.Data_abertura, '%d/%m/%Y') > STR_TO_DATE(b2.Data_abertura, '%d/%m/%Y');

-- Escopo confirmado: 891 pares Processo/Lote afetados
SELECT COUNT(DISTINCT b1.Processo, b1.Lote) AS qtd_afetados
FROM leilao_bruto b1
JOIN leilao_bruto b2
    ON b1.Processo = b2.Processo AND b1.Lote = b2.Lote
    AND b1.Praca = 2 AND b2.Praca = 3
    AND STR_TO_DATE(b2.Data_abertura, '%d/%m/%Y') < STR_TO_DATE(b1.Data_abertura, '%d/%m/%Y');

-- Confirmação de que nenhum caso já tinha Praça 1 (sem risco de conflito)
SELECT DISTINCT b1.Processo, b1.Lote
FROM leilao_bruto b1
JOIN leilao_bruto b2
    ON b1.Processo = b2.Processo AND b1.Lote = b2.Lote
    AND b1.Praca = 2 AND b2.Praca = 3
    AND STR_TO_DATE(b2.Data_abertura, '%d/%m/%Y') < STR_TO_DATE(b1.Data_abertura, '%d/%m/%Y')
WHERE EXISTS (
    SELECT 1 FROM leilao_bruto b3
    WHERE b3.Processo = b1.Processo AND b3.Lote = b1.Lote AND b3.Praca = 1
);


-- 04_correcao_update.sql
-- Índice necessário para performance (evita timeout, lição do Dia 3)
ALTER TABLE leilao_bruto ADD INDEX idx_processo_lote (Processo, Lote);

-- Tabela temporária com os casos a corrigir
CREATE TEMPORARY TABLE casos_para_corrigir AS
SELECT DISTINCT b1.Processo, b1.Lote
FROM leilao_bruto b1
JOIN leilao_bruto b2
    ON b1.Processo = b2.Processo AND b1.Lote = b2.Lote
    AND b1.Praca = 2 AND b2.Praca = 3
    AND STR_TO_DATE(b2.Data_abertura, '%d/%m/%Y') < STR_TO_DATE(b1.Data_abertura, '%d/%m/%Y');

-- Aplicação da correção
SET SQL_SAFE_UPDATES = 0;
UPDATE leilao_bruto b
JOIN casos_para_corrigir c ON b.Processo = c.Processo AND b.Lote = c.Lote
SET b.Praca = 1
WHERE b.Praca = 3;
SET SQL_SAFE_UPDATES = 1;


-- 05_validacao_correcao.sql
-- Não deve sobrar nenhuma inversão
SELECT COUNT(*)
FROM leilao_bruto b1
JOIN leilao_bruto b2
    ON b1.Processo = b2.Processo AND b1.Lote = b2.Lote
    AND b1.Praca < b2.Praca
    AND STR_TO_DATE(b1.Data_abertura, '%d/%m/%Y') > STR_TO_DATE(b2.Data_abertura, '%d/%m/%Y');

-- Total de linhas deve permanecer 35.298
SELECT COUNT(*) FROM leilao_bruto;
06_repopulacao_praca_leilao.sql
sql
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE leilao;
TRUNCATE TABLE praca;

INSERT INTO praca (numero_praca, data_abertura, data_fechamento, dia_semana)
SELECT DISTINCT b.Praca, STR_TO_DATE(b.Data_abertura, '%d/%m/%Y'),
       STR_TO_DATE(b.Data_fechamento, '%d/%m/%Y'), b.Dia_semana
FROM leilao_bruto b
WHERE b.Data_abertura IS NOT NULL;

INSERT INTO leilao (Id_praca, id_lote, id_processo, id_leiloeiro)
SELECT DISTINCT p.Id_praca, lt.id_lote, pr.id_processo, le.id_leiloeiro
FROM leilao_bruto b
LEFT JOIN praca p ON p.numero_praca = b.Praca
    AND p.data_abertura = STR_TO_DATE(b.Data_abertura, '%d/%m/%Y')
    AND p.data_fechamento = STR_TO_DATE(b.Data_fechamento, '%d/%m/%Y')
    AND p.dia_semana = b.Dia_semana
LEFT JOIN lote lt ON lt.item_id_origem = b.Item_ID
LEFT JOIN processo pr ON pr.numero_processo_origem = b.Processo
LEFT JOIN leiloeiro le ON le.nome = b.Leiloeiro;

SET FOREIGN_KEY_CHECKS = 1;


-- 07_validacao_final_modelo.sql
SELECT COUNT(*) FROM praca;   -- esperado: 11.274
SELECT COUNT(*) FROM leilao;  -- esperado: 35.298

SELECT numero_praca, data_abertura, data_fechamento, dia_semana, COUNT(*)
FROM praca
GROUP BY numero_praca, data_abertura, data_fechamento, dia_semana
HAVING COUNT(*) > 1;

SELECT COUNT(*) FROM leilao le
LEFT JOIN praca p ON le.Id_praca = p.Id_praca
WHERE le.Id_praca IS NOT NULL AND p.Id_praca IS NULL;