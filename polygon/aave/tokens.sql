CREATE TABLE IF NOT EXISTS aave.tokens (   
    version text,
    symbol  text,
    contract_address bytea,
    "aToken" bytea,
    "stableDebtToken" bytea,
    "variableDebtToken" bytea,
    decimals numeric,
    PRIMARY KEY (version, contract_address),
    UNIQUE (version, contract_address)
    
);

CREATE OR REPLACE FUNCTION aave.insert_tokens(start_ts timestamptz, end_ts timestamptz=now(), start_block numeric=0, end_block numeric=9e18) RETURNS integer
LANGUAGE plpgsql AS $function$
DECLARE r integer;
BEGIN
WITH rows AS (
    INSERT INTO aave.tokens (
    version,
    symbol,
    contract_address,
    "aToken",
    "stableDebtToken",
    "variableDebtToken",
    decimals
    )
    ((SELECT
    version,
    symbol,
    pools.contract_address,
    "aToken",
    "stableDebtToken",
    "variableDebtToken",
    decimals
FROM (
SELECT 
    '2' AS version,
    asset AS contract_address,
    "aToken",
    "stableDebtToken",
    "variableDebtToken"
FROM aave_v2."LendingPoolConfigurator_evt_ReserveInitialized" 
UNION ALL
SELECT 
    '3' AS version,
    asset AS contract_address,
    "aToken",
    "stableDebtToken",
    "variableDebtToken"
FROM aave_v3."PoolConfigurator_evt_ReserveInitialized"
) pools
LEFT JOIN erc20.tokens erc20tokens
ON pools.contract_address = erc20tokens.contract_address

    
    ))
    ON CONFLICT DO NOTHING
    RETURNING 1
)
SELECT count(*) INTO r from rows;
RETURN r;
END
$function$;

SELECT aave.insert_tokens(DATE_TRUNC('day','2019-01-24'::timestamptz),DATE_TRUNC('day',NOW()) )
WHERE NOT EXISTS (
    SELECT *
    FROM aave.aave_tokens
);


INSERT INTO cron.job (schedule, command)
VALUES ('15,45 * * * *', $$
    SELECT aave.tokens(
        (SELECT NOW() - interval '1 year'),
        (SELECT NOW());
	
$$)