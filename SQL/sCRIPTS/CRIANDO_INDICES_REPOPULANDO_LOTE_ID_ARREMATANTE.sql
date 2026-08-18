-- Criando indices

ALTER TABLE lote ADD INDEX idx_item_id_origem (item_id_origem);
ALTER TABLE leilao_bruto ADD INDEX idx_item_id (Item_ID);
ALTER TABLE arrematante ADD INDEX idx_nome_tel_email (nome, telefone, email);


-- repopulando o lote com o id_arrematante, já que antes populamos lote antes de arrematante
UPDATE lote l
JOIN leilao_bruto b ON b.Item_ID = l.item_id_origem
LEFT JOIN arrematante a
    ON a.nome = b.Arrematante
    AND a.telefone = b.Telefone_Arrematante
    AND a.email = b.Email_Arrematante
SET l.id_arrematante = a.id_arrematante
WHERE l.id_lote > 0;

-- validação da quantidade de lotes com arrematante e TOTAL de lotes mesmo sem arrematantes
SELECT COUNT(*) FROM lote WHERE id_arrematante IS NOT NULL;  -- deve dar 8780
SELECT COUNT(*) FROM lote WHERE id_arrematante IS NULL;      -- deve dar 26518