import React, { useEffect, useState } from "react";

// Conversor de Moedas - Single-file React component
// Requisitos: TailwindCSS configurado no projeto (ou remova classes Tailwind)
// API pública usada: exchangerate.host (não requer chave)

export default function CurrencyConverter() {
  const [symbols, setSymbols] = useState({});
  const [base, setBase] = useState("BRL");
  const [target, setTarget] = useState("USD");
  const [amount, setAmount] = useState(1);
  const [rate, setRate] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [history, setHistory] = useState(() => {
    try {
      return JSON.parse(localStorage.getItem("conv_history")) || [];
    } catch {
      return [];
    }
  });
  const [favorites, setFavorites] = useState(() => {
    try {
      return JSON.parse(localStorage.getItem("conv_favs")) || [];
    } catch {
      return [];
    }
  });

  const fallbackRates = {
    USD: 1,
    BRL: 5.0,
    EUR: 0.9,
    GBP: 0.78,
    JPY: 150,
  };

  useEffect(() => {
    let mounted = true;
    fetch("https://api.exchangerate.host/symbols")
      .then((r) => r.json())
      .then((data) => {
        if (!mounted) return;
        if (data && data.symbols) setSymbols(data.symbols);
      })
      .catch(() => {
        setSymbols(
          Object.fromEntries(
            Object.keys(fallbackRates).map((c) => [c, { description: c }])
          )
        );
      });
    return () => (mounted = false);
  }, []);

  useEffect(() => {
    if (!base || !target) return;
    setLoading(true);
    setError(null);
    fetch(`https://api.exchangerate.host/convert?from=${base}&to=${target}`)
      .then((r) => r.json())
      .then((data) => {
        if (data && typeof data.result === "number") {
          setRate(data.result);
        } else if (data && data.info && data.info.rate) {
          setRate(data.info.rate);
        } else {
          const r = (fallbackRates[target] || 1) / (fallbackRates[base] || 1);
          setRate(r);
          setError("Usando taxa de câmbio de fallback (offline)");
        }
      })
      .catch(() => {
        const r = (fallbackRates[target] || 1) / (fallbackRates[base] || 1);
        setRate(r);
        setError("Falha ao buscar taxas — usando fallback");
      })
      .finally(() => setLoading(false));
  }, [base, target]);

  useEffect(() => {
    localStorage.setItem("conv_history", JSON.stringify(history));
  }, [history]);

  useEffect(() => {
    localStorage.setItem("conv_favs", JSON.stringify(favorites));
  }, [favorites]);

  function formatNumber(n) {
    return Number(n).toLocaleString(undefined, { maximumFractionDigits: 6 });
  }

  function handleConvert() {
    if (!rate) return null;
    const result = Number(amount || 0) * Number(rate);
    const entry = {
      ts: new Date().toISOString(),
      base,
      target,
      amount: Number(amount),
      rate: Number(rate),
      result: Number(result),
    };
    setHistory((h) => [entry, ...h].slice(0, 20));
    return result;
  }

  function handleSwap() {
    setBase((b) => {
      setTarget(b);
      return target;
    });
  }

  function toggleFavorite(pair) {
    setFavorites((f) => {
      const exists = f.find((x) => x === pair);
      if (exists) return f.filter((x) => x !== pair);
      return [pair, ...f].slice(0, 10);
    });
  }

  const result = rate ? Number(amount || 0) * Number(rate) : null;

  return (
    <div className="max-w-4xl mx-auto p-6">
      <header className="mb-6">
        <h1 className="text-2xl font-bold">Conversor de Moedas</h1>
        <p className="text-sm text-gray-600">Simples, acessível e responsivo — usa exchangerate.host</p>
      </header>

      <main className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <section className="md:col-span-2 bg-white p-4 rounded-2xl shadow-sm">
          <div className="flex gap-3 items-center mb-4">
            <label className="flex-1">
              <div className="text-xs text-gray-500">Valor</div>
              <input
                className="w-full mt-1 p-2 border rounded-md"
                inputMode="decimal"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
              />
            </label>

            <button
              aria-label="trocar"
              onClick={handleSwap}
              className="mt-6 bg-gray-100 p-2 rounded-full"
              title="Trocar moedas"
            >
              ⇄
            </button>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <div className="text-xs text-gray-500">De</div>
              <select
                value={base}
                onChange={(e) => setBase(e.target.value)}
                className="w-full mt-1 p-2 border rounded-md"
              >
                {Object.keys(symbols).length === 0 && (
                  <option>Carregando...</option>
                )}
                {Object.entries(symbols).map(([code, meta]) => (
                  <option key={code} value={code}>
                    {code} — {meta.description || ""}
                  </option>
                ))}
              </select>
            </div>

            <div>
              <div className="text-xs text-gray-500">Para</div>
              <select
                value={target}
                onChange={(e) => setTarget(e.target.value)}
                className="w-full mt-1 p-2 border rounded-md"
              >
                {Object.entries(symbols).map(([code, meta]) => (
                  <option key={code} value={code}>
                    {code} — {meta.description || ""}
                  </option>
                ))}
              </select>
            </div>
          </div>

          <div className="mt-4 flex items-center gap-3">
            <button
              onClick={() => {
                const converted = handleConvert();
                if (converted === null) setError("Conversão indisponível");
              }}
              className="px-4 py-2 bg-blue-600 text-white rounded-lg shadow-sm"
            >
              Converter
            </button>

            <button
              onClick={() => toggleFavorite(`${base}_${target}`)}
              className="px-3 py-2 bg-gray-100 rounded-lg"
            >
              {favorites.includes(`${base}_${target}`) ? "★ Favorito" : "☆ Favoritar"}
            </button>

            <div className="ml-auto text-sm text-gray-500">Taxa: {loading ? "..." : rate ? formatNumber(rate) : "—"}</div>
          </div>

          <div className="mt-6 bg-gray-50 p-4 rounded-md">
            <div className="text-sm text-gray-600">Resultado</div>
            <div className="mt-2 text-xl font-semibold">
              {loading && <span>Calculando...</span>}
              {!loading && rate && (
                <span>
                  {formatNumber(result)} {target}
                  <span className="text-sm ml-2 text-gray-500">({formatNumber(amount)} {base} → {formatNumber(rate)} )</span>
                </span>
              )}
              {!loading && !rate && <span>Sem resultado</span>}
            </div>
            {error && <div className="mt-2 text-sm text-red-600">{error}</div>}
            <div className="mt-3 flex gap-2">
              <button
                onClick={() => navigator.clipboard?.writeText(result?.toString() || "")}
                className="px-3 py-1 border rounded-md text-sm"
              >
                Copiar valor
              </button>

              <button
                onClick={() => {
                  const csv = `data:text/csv;charset=utf-8,base,target,amount,rate,result\n${base},${target},${amount},${rate},${result}`;
                  const encoded = encodeURI(csv);
                  const a = document.createElement("a");
                  a.href = encoded;
                  a.download = `conversao_${base}_${target}.csv`;
                  a.click();
                }}
                className="px-3 py-1 border rounded-md text-sm"
              >
                Baixar CSV
              </button>
            </div>
          </div>
        </section>

        <aside className="bg-white p-4 rounded-2xl shadow-sm">
          <div className="flex items-center justify-between">
            <h2 className="font-semibold">Atalhos</h2>
            <button
              onClick={() => {
                setHistory([]);
                setFavorites([]);
                localStorage.removeItem("conv_history");
                localStorage.removeItem("conv_favs");
              }}
              className="text-xs text-red-500"
            >
              limpar
            </button>
          </div>

          <div className="mt-3">
            <div className="text-xs text-gray-500">Favoritos</div>
            <div className="mt-2 flex flex-col gap-2">
              {favorites.length === 0 && <div className="text-sm text-gray-500">(Nenhum)</div>}
              {favorites.map((f) => {
                const [b, t] = f.split("_");
                return (
                  <button
                    key={f}
                    onClick={() => {
                      setBase(b);
                      setTarget(t);
                    }}
                    className="text-left p-2 border rounded-md"
                  >
                    {b} → {t}
                  </button>
                );
              })}
            </div>
          </div>

          <div className="mt-4">
            <div className="text-xs text-gray-500">Histórico (últimos 20)</div>
            <div className="mt-2 max-h-48 overflow-auto">
              {history.length === 0 && <div className="text-sm text-gray-500">Sem histórico</div>}
              {history.map((h, i) => (
                <div key={i} className="p-2 border-b last:border-b-0">
                  <div className="text-sm">
                    {new Date(h.ts).toLocaleString()} — {h.amount} {h.base} → {formatNumber(h.result)} {h.target}
                  </div>
                  <div className="text-xs text-gray-400">taxa {formatNumber(h.rate)}</div>
                </div>
              ))}
            </div>
          </div>

          <div className="mt-4">
            <div className="text-xs text-gray-500">Dicas</div>
            <ul className="mt-2 text-sm text-gray-600 list-disc list-inside">
              <li>Troque rapidamente com o botão ⇄</li>
              <li>Favoritos são salvos no navegador</li>
              <li>Se a API falhar, o app usa taxas de fallback</li>
            </ul>
          </div>
        </aside>
      </main>

      <footer className="mt-6 text-sm text-gray-500 text-center">Feito com ❤️ — fonte de taxas: exchangerate.host</footer>
    </div>
  );
}
