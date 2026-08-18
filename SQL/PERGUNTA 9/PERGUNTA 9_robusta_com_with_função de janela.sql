/*
	Parte 2: Versão robusta com função de janela (curva completa)

Agora vamos ver a curva completa de concentração, não só um ponto de corte fixo em 10%. Isso usa SUM() OVER (ORDER BY ...) — uma função de janela, que calcula uma soma acumulada linha por linha, sem precisar agrupar tudo numa única linha de resultado.
*/

WITH gasto_por_arrematante AS (
    SELECT
        a.id_arrematante,
        a.nome,
        SUM(l.valor_lance_final) AS valor_gasto
    FROM arrematante a
    JOIN lote l ON l.id_arrematante = a.id_arrematante
    GROUP BY a.id_arrematante, a.nome
)
SELECT
    nome,
    valor_gasto,
    ROUND(SUM(valor_gasto) OVER (ORDER BY valor_gasto DESC) / 
          SUM(valor_gasto) OVER () * 100, 2) AS pct_acumulado
FROM gasto_por_arrematante
ORDER BY valor_gasto DESC;

/*
	Explicando a novidade — função de janela (OVER)
SUM(valor_gasto) OVER (ORDER BY valor_gasto DESC) — diferente do GROUP BY (que "achata" várias linhas em uma), a função de janela mantém cada linha visível, mas calcula uma soma progressiva: a 1ª linha soma só ela mesma, a 2ª linha soma ela + a anterior, e assim por diante — é a "soma acumulada" (running total)
SUM(valor_gasto) OVER () — sem ORDER BY dentro do OVER, isso soma todas as linhas (o total geral), repetido em cada linha do resultado — usamos isso como denominador pra calcular o percentual acumulado
WITH gasto_por_arrematante AS (...) — uma CTE (Common Table Expression), que é basicamente "nomear uma subconsulta" pra deixar a query principal mais limpa — calculamos o valor por arrematante primeiro, e só depois aplicamos a função de janela em cima desse resultado já pronto

Repara numa coisa importante: na linha 24 (Thiago Zago), o acumulado está em 14,79% — praticamente idêntico ao 14,78% que calculamos na versão simplificada com LIMIT 24. As duas abordagens se validam mutuamente ✅ (pequena diferença de arredondamento, nada preocupante).

Insight completo da Pergunta 9 (concentração/Pareto)

A distribuição de valor entre arrematantes é notavelmente equilibrada — não existe o clássico efeito Pareto extremo (80/20).

Alguns pontos que chamam atenção na curva:

Nem o maior comprador domina isoladamente: Mateus Loureiro, o topo do ranking, responde por apenas 0,77% do valor total — um número baixíssimo pra quem é "o maior". Isso já indica ausência de concentração forte no topo.
Crescimento gradual e constante: olhando a progressão (0,77% → 1,52% → 2,22% → 2,90%...), cada arrematante adicional contribui com incrementos muito parecidos entre si (~0,5-0,7 p.p. cada) — não há "saltos" grandes que indicariam outliers dominantes.
Para chegar a apenas ¼ do valor total (24,46%), já precisamos de 42 arrematantes (17% do total de 243) — bem longe da regra "80/20" clássica, que preveria algo como 20% dos arrematantes concentrando 80% do valor.
Conclusão de negócio

Não existe um pequeno grupo de "baleias" dominando o mercado de arrematação neste conjunto de dados. O valor está distribuído de forma relativamente democrática entre um número grande de compradores recorrentes de porte similar — isso é uma informação valiosa para quem for investir ou analisar risco de concentração nesse mercado (ex: um fundo não dependeria de poucos "grandes clientes" para sustentar o volume de negócios).


*/