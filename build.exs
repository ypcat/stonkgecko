# stonkgecko — a single self-contained Elixir script that builds a static,
# CoinGecko-inspired stock tracker for the world's top 10 stock markets,
# ranking each market's largest companies by market capitalization.
#
# Run with:  elixir build.exs
# Output:    public/index.html  (deployed to GitHub Pages by the daily Action)
#
# Data strategy (no API key required):
#   * Live price comes from Yahoo Finance's v8 chart endpoint (most reliable,
#     needs no crumb/cookie).
#   * Market cap = price x shares_outstanding, using embedded share counts.
#   * We opportunistically try the v7 quote endpoint (cookie+crumb handshake)
#     to override with the *exact* reported market cap when it's reachable.
#   * Everything is converted to USD via live FX rates (also from the chart
#     endpoint) so markets are comparable; ranking is within each market.
# If FMP_API_KEY is set, the exact market cap from Financial Modeling Prep is
# preferred when available.

Mix.install([{:req, "~> 0.5"}])

defmodule Stonk do
  @user_agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"

  # The world's top 10 stock markets by total market capitalization.
  # Each market lists its largest companies (Yahoo-formatted tickers); the
  # script fetches live data and re-ranks them by market cap at build time.
  def markets do
    [
      %{name: "NASDAQ", country: "United States", flag: "🇺🇸", currency: "USD",
        tickers: ~w(AAPL MSFT NVDA GOOGL AMZN META TSLA AVGO COST NFLX)},
      %{name: "NYSE", country: "United States", flag: "🇺🇸", currency: "USD",
        tickers: ~w(BRK-B JPM WMT V JNJ XOM PG HD BAC KO)},
      %{name: "Shanghai Stock Exchange", country: "China", flag: "🇨🇳", currency: "CNY",
        tickers: ~w(600519.SS 601398.SS 601857.SS 600941.SS 601288.SS 601988.SS 600036.SS 601628.SS 600900.SS 601318.SS)},
      %{name: "Euronext", country: "European Union", flag: "🇪🇺", currency: "EUR",
        tickers: ~w(MC.PA RMS.PA OR.PA TTE.PA SAN.PA AIR.PA SU.PA EL.PA ASML.AS PRX.AS)},
      %{name: "Japan Exchange (Tokyo)", country: "Japan", flag: "🇯🇵", currency: "JPY",
        tickers: ~w(7203.T 8306.T 6758.T 9984.T 6861.T 9983.T 8035.T 6098.T 4063.T 9432.T)},
      %{name: "Shenzhen Stock Exchange", country: "China", flag: "🇨🇳", currency: "CNY",
        tickers: ~w(300750.SZ 000858.SZ 002594.SZ 000333.SZ 300760.SZ 000651.SZ 002415.SZ 000001.SZ 002230.SZ 300059.SZ)},
      %{name: "National Stock Exchange of India", country: "India", flag: "🇮🇳", currency: "INR",
        tickers: ~w(RELIANCE.NS TCS.NS HDFCBANK.NS BHARTIARTL.NS ICICIBANK.NS INFY.NS SBIN.NS LT.NS ITC.NS HINDUNILVR.NS)},
      %{name: "Hong Kong Stock Exchange", country: "Hong Kong", flag: "🇭🇰", currency: "HKD",
        tickers: ~w(0700.HK 0941.HK 1299.HK 0939.HK 1398.HK 3690.HK 9988.HK 0388.HK 2318.HK 0005.HK)},
      %{name: "Toronto Stock Exchange", country: "Canada", flag: "🇨🇦", currency: "CAD",
        tickers: ~w(RY.TO TD.TO SHOP.TO ENB.TO BN.TO CNR.TO CP.TO BMO.TO CNQ.TO BNS.TO)},
      %{name: "Saudi Exchange (Tadawul)", country: "Saudi Arabia", flag: "🇸🇦", currency: "SAR",
        tickers: ~w(2222.SR 1120.SR 2010.SR 7010.SR 1180.SR 2350.SR 1211.SR 7020.SR 1010.SR 2020.SR)}
    ]
  end

  # Common name + shares outstanding (billions) per ticker. Shares change
  # slowly; live price x these gives a market cap good enough to rank by, and
  # is the fallback whenever the exact quote endpoint is unreachable.
  def meta do
    %{
      "BRK-B" => {"Berkshire Hathaway", 2.16}, "JPM" => {"JPMorgan Chase", 2.78},
      "WMT" => {"Walmart", 8.03}, "V" => {"Visa", 1.94}, "JNJ" => {"Johnson & Johnson", 2.41},
      "XOM" => {"Exxon Mobil", 4.34}, "PG" => {"Procter & Gamble", 2.35}, "HD" => {"Home Depot", 0.995},
      "BAC" => {"Bank of America", 7.6}, "KO" => {"Coca-Cola", 4.31},
      "AAPL" => {"Apple", 14.84}, "MSFT" => {"Microsoft", 7.43}, "NVDA" => {"NVIDIA", 24.4},
      "GOOGL" => {"Alphabet", 12.2}, "AMZN" => {"Amazon", 10.6}, "META" => {"Meta Platforms", 2.52},
      "TSLA" => {"Tesla", 3.22}, "AVGO" => {"Broadcom", 4.7}, "COST" => {"Costco", 0.443},
      "NFLX" => {"Netflix", 0.426},
      "MC.PA" => {"LVMH", 0.5}, "RMS.PA" => {"Hermès", 0.105}, "OR.PA" => {"L'Oréal", 0.535},
      "TTE.PA" => {"TotalEnergies", 2.34}, "SAN.PA" => {"Sanofi", 1.25}, "AIR.PA" => {"Airbus", 0.79},
      "SU.PA" => {"Schneider Electric", 0.566}, "EL.PA" => {"EssilorLuxottica", 0.458},
      "ASML.AS" => {"ASML", 0.393}, "PRX.AS" => {"Prosus", 2.46},
      "7203.T" => {"Toyota Motor", 13.0}, "8306.T" => {"Mitsubishi UFJ", 11.8},
      "6758.T" => {"Sony Group", 6.15}, "9984.T" => {"SoftBank Group", 1.44},
      "6861.T" => {"Keyence", 0.243}, "9983.T" => {"Fast Retailing", 0.318},
      "8035.T" => {"Tokyo Electron", 0.466}, "6098.T" => {"Recruit Holdings", 1.5},
      "4063.T" => {"Shin-Etsu Chemical", 1.94}, "9432.T" => {"NTT", 9.06},
      "600519.SS" => {"Kweichow Moutai", 1.26}, "601398.SS" => {"ICBC", 356.0},
      "601857.SS" => {"PetroChina", 183.0}, "600941.SS" => {"China Mobile", 21.5},
      "601288.SS" => {"Agricultural Bank of China", 350.0}, "601988.SS" => {"Bank of China", 294.0},
      "600036.SS" => {"China Merchants Bank", 25.2}, "601628.SS" => {"China Life Insurance", 28.3},
      "600900.SS" => {"China Yangtze Power", 24.5}, "601318.SS" => {"Ping An Insurance", 18.2},
      "300750.SZ" => {"CATL", 4.4}, "000858.SZ" => {"Wuliangye Yibin", 3.88},
      "002594.SZ" => {"BYD", 2.91}, "000333.SZ" => {"Midea Group", 7.0},
      "300760.SZ" => {"Mindray", 1.21}, "000651.SZ" => {"Gree Electric", 5.6},
      "002415.SZ" => {"Hikvision", 9.2}, "000001.SZ" => {"Ping An Bank", 19.4},
      "002230.SZ" => {"iFlytek", 2.31}, "300059.SZ" => {"East Money", 15.8},
      "RELIANCE.NS" => {"Reliance Industries", 13.5}, "TCS.NS" => {"Tata Consultancy Services", 3.62},
      "HDFCBANK.NS" => {"HDFC Bank", 7.65}, "BHARTIARTL.NS" => {"Bharti Airtel", 5.98},
      "ICICIBANK.NS" => {"ICICI Bank", 7.06}, "INFY.NS" => {"Infosys", 4.15},
      "SBIN.NS" => {"State Bank of India", 8.92}, "LT.NS" => {"Larsen & Toubro", 1.375},
      "ITC.NS" => {"ITC", 12.5}, "HINDUNILVR.NS" => {"Hindustan Unilever", 2.35},
      "0700.HK" => {"Tencent", 9.13}, "0941.HK" => {"China Mobile", 21.5},
      "1299.HK" => {"AIA Group", 11.4}, "0939.HK" => {"China Construction Bank", 250.0},
      "1398.HK" => {"ICBC", 356.0}, "3690.HK" => {"Meituan", 6.12}, "9988.HK" => {"Alibaba", 19.0},
      "0388.HK" => {"HKEX", 1.27}, "2318.HK" => {"Ping An Insurance", 18.2}, "0005.HK" => {"HSBC Holdings", 17.6},
      "RY.TO" => {"Royal Bank of Canada", 1.41}, "TD.TO" => {"Toronto-Dominion Bank", 1.75},
      "SHOP.TO" => {"Shopify", 1.29}, "ENB.TO" => {"Enbridge", 2.18}, "BN.TO" => {"Brookfield", 1.64},
      "CNR.TO" => {"Canadian National Railway", 0.625}, "CP.TO" => {"Canadian Pacific Kansas City", 0.93},
      "BMO.TO" => {"Bank of Montreal", 0.73}, "CNQ.TO" => {"Canadian Natural Resources", 2.1},
      "BNS.TO" => {"Bank of Nova Scotia", 1.24},
      "2222.SR" => {"Saudi Aramco", 242.0}, "1120.SR" => {"Al Rajhi Bank", 4.0},
      "2010.SR" => {"SABIC", 3.0}, "7010.SR" => {"STC", 5.0}, "1180.SR" => {"Saudi National Bank", 5.98},
      "2350.SR" => {"Saudi Kayan", 1.5}, "1211.SR" => {"Maaden", 3.78},
      "7020.SR" => {"Etihad Etisalat (Mobily)", 0.77}, "1010.SR" => {"Riyad Bank", 3.0},
      "2020.SR" => {"SABIC Agri-Nutrients", 0.476}
    }
  end

  # ---- Data fetching -------------------------------------------------------

  # FX rate: 1 unit of `cur` -> USD, via Yahoo chart "<CUR>USD=X".
  def fx_rate("USD"), do: 1.0
  def fx_rate(cur) do
    case chart("#{cur}USD=X") do
      {:ok, price, _prev} when is_number(price) and price > 0 -> price
      _ -> nil
    end
  end

  # Yahoo v8 chart endpoint -> {:ok, last_price, previous_close} | :error
  def chart(symbol) do
    url = "https://query1.finance.yahoo.com/v8/finance/chart/#{URI.encode(symbol)}"

    case Req.get(url,
           params: [interval: "1d", range: "5d"],
           headers: [{"user-agent", @user_agent}],
           retry: :transient, max_retries: 3, receive_timeout: 20_000
         ) do
      {:ok, %{status: 200, body: %{"chart" => %{"result" => [r | _]}}}} ->
        meta = r["meta"] || %{}
        price = meta["regularMarketPrice"]
        prev = meta["chartPreviousClose"] || meta["previousClose"]
        if is_number(price), do: {:ok, price * 1.0, num(prev)}, else: :error

      _ ->
        :error
    end
  end

  defp num(n) when is_number(n), do: n * 1.0
  defp num(_), do: nil

  # Optional exact market caps (local currency) keyed by ticker, via the v7
  # quote endpoint with a cookie+crumb handshake. Returns %{} if unreachable.
  def exact_market_caps(tickers) do
    with {:ok, crumb, cookies} <- crumb_handshake() do
      tickers
      |> Enum.chunk_every(40)
      |> Enum.flat_map(fn batch ->
        url = "https://query1.finance.yahoo.com/v7/finance/quote"

        case Req.get(url,
               params: [symbols: Enum.join(batch, ","), crumb: crumb],
               headers: [{"user-agent", @user_agent}, {"cookie", cookies}],
               receive_timeout: 20_000
             ) do
          {:ok, %{status: 200, body: %{"quoteResponse" => %{"result" => results}}}} ->
            for q <- results, is_number(q["marketCap"]), do: {q["symbol"], q["marketCap"] * 1.0}

          _ ->
            []
        end
      end)
      |> Map.new()
    else
      _ -> %{}
    end
  end

  defp crumb_handshake do
    with {:ok, resp} <-
           Req.get("https://fc.yahoo.com/",
             headers: [{"user-agent", @user_agent}], redirect: false, receive_timeout: 15_000
           ),
         cookies when cookies != "" <- collect_cookies(resp),
         {:ok, %{status: 200, body: crumb}} when is_binary(crumb) and crumb != "" <-
           Req.get("https://query1.finance.yahoo.com/v1/test/getcrumb",
             headers: [{"user-agent", @user_agent}, {"cookie", cookies}], receive_timeout: 15_000
           ) do
      {:ok, String.trim(crumb), cookies}
    else
      _ -> :error
    end
  end

  defp collect_cookies(%Req.Response{} = resp) do
    resp
    |> Req.Response.get_header("set-cookie")
    |> Enum.map(&(&1 |> String.split(";", parts: 2) |> hd()))
    |> Enum.join("; ")
  end

  # ---- Assembly ------------------------------------------------------------

  def build do
    IO.puts("stonkgecko: fetching market data...")
    fmp_key = System.get_env("FMP_API_KEY")
    all_tickers = markets() |> Enum.flat_map(& &1.tickers)

    currencies = markets() |> Enum.map(& &1.currency) |> Enum.uniq()
    fx = Map.new(currencies, fn c -> {c, fx_rate(c)} end)
    IO.puts("  fx rates: #{inspect(fx)}")

    exact = exact_market_caps(all_tickers)
    fmp = if fmp_key, do: fmp_quotes(all_tickers, fmp_key), else: %{}
    IO.puts("  exact market caps (yahoo): #{map_size(exact)} | fmp: #{map_size(fmp)}")

    markets_data =
      Enum.map(markets(), fn m ->
        rate = Map.get(fx, m.currency) || 1.0

        rows =
          m.tickers
          |> Enum.map(&row(&1, m.currency, rate, exact, fmp))
          |> Enum.reject(&is_nil/1)
          |> Enum.sort_by(& &1.mcap_usd, :desc)
          |> Enum.with_index(1)
          |> Enum.map(fn {row, rank} -> Map.put(row, :rank, rank) end)

        Map.put(m, :rows, rows)
      end)

    total = markets_data |> Enum.flat_map(& &1.rows) |> Enum.map(& &1.mcap_usd) |> Enum.sum()
    counted = markets_data |> Enum.flat_map(& &1.rows) |> length()
    IO.puts("  priced #{counted} stocks, total market cap $#{Render.human_usd(total)}")

    html = Render.page(markets_data, total)
    File.mkdir_p!("public")
    File.write!("public/index.html", html)
    File.write!("public/.nojekyll", "")
    File.write!("public/CNAME", "stonkgecko.com")
    IO.puts("stonkgecko: wrote public/index.html (#{byte_size(html)} bytes)")
  end

  defp row(ticker, currency, rate, exact, fmp) do
    {name, shares_b} = Map.get(meta(), ticker, {ticker, nil})

    case chart(ticker) do
      {:ok, price, prev} ->
        change =
          if is_number(prev) and prev > 0, do: (price - prev) / prev * 100.0, else: nil

        mcap_local =
          cond do
            is_number(fmp[ticker]) -> fmp[ticker]
            is_number(exact[ticker]) -> exact[ticker]
            is_number(shares_b) -> price * shares_b * 1.0e9
            true -> nil
          end

        if is_number(mcap_local) do
          %{ticker: ticker, name: name, currency: currency, price: price,
            change: change, mcap_usd: mcap_local * rate}
        end

      :error ->
        IO.puts("  ! no price for #{ticker}")
        nil
    end
  end

  # Financial Modeling Prep batched quote (only used if FMP_API_KEY is set).
  defp fmp_quotes(tickers, key) do
    url = "https://financialmodelingprep.com/api/v3/quote/#{Enum.join(tickers, ",")}"

    case Req.get(url, params: [apikey: key], receive_timeout: 20_000) do
      {:ok, %{status: 200, body: results}} when is_list(results) ->
        for q <- results, is_number(q["marketCap"]), do: {q["symbol"], q["marketCap"] * 1.0}
      _ -> []
    end
    |> Map.new()
  end
end

defmodule Render do
  def human_usd(n) when not is_number(n), do: "—"
  def human_usd(n) when n >= 1.0e12, do: "$#{f(n / 1.0e12)}T"
  def human_usd(n) when n >= 1.0e9, do: "$#{f(n / 1.0e9)}B"
  def human_usd(n) when n >= 1.0e6, do: "$#{f(n / 1.0e6)}M"
  def human_usd(n), do: "$#{f(n)}"

  defp f(x) do
    :erlang.float_to_binary(x * 1.0, decimals: 2)
  end

  def price(p, cur) do
    sym = %{"USD" => "$", "EUR" => "€", "JPY" => "¥", "CNY" => "¥", "INR" => "₹",
            "HKD" => "HK$", "CAD" => "C$", "SAR" => "﷼"}
    "#{Map.get(sym, cur, "")}#{:erlang.float_to_binary(p * 1.0, decimals: 2)}"
  end

  def change_badge(nil), do: ~s(<span class="chg flat">—</span>)
  def change_badge(c) do
    cls = if c >= 0, do: "up", else: "down"
    arrow = if c >= 0, do: "▲", else: "▼"
    val = :erlang.float_to_binary(abs(c) * 1.0, decimals: 2)
    ~s(<span class="chg #{cls}">#{arrow} #{val}%</span>)
  end

  def e(s), do: s |> to_string() |> String.replace("&", "&amp;") |> String.replace("<", "&lt;") |> String.replace(">", "&gt;")

  def page(markets, total) do
    stocks = markets |> Enum.flat_map(& &1.rows) |> length()
    nav =
      markets
      |> Enum.with_index(1)
      |> Enum.map(fn {m, i} -> ~s(<a href="#m#{i}">#{m.flag} #{e(m.name)}</a>) end)
      |> Enum.join("")

    sections =
      markets
      |> Enum.with_index(1)
      |> Enum.map(fn {m, i} -> market_section(m, i) end)
      |> Enum.join("\n")

    """
    <!doctype html>
    <html lang="en">
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>stonkgecko — World Stock Markets by Market Cap</title>
    <meta name="description" content="Daily-updated ranking of the world's top 10 stock markets and their largest companies by market capitalization.">
    <style>#{css()}</style>
    </head>
    <body>
    <header class="topbar">
      <div class="wrap">
        <div class="brand">🦎 <span>stonk<b>gecko</b></span></div>
        <nav class="markets-nav">#{nav}</nav>
      </div>
    </header>

    <section class="hero">
      <div class="wrap">
        <h1>World Stock Markets by Market Cap</h1>
        <p class="sub">Top 10 exchanges, largest companies ranked by market capitalization — refreshed daily.</p>
        <div class="stats">
          <div class="stat"><span class="k">Markets</span><span class="v">#{length(markets)}</span></div>
          <div class="stat"><span class="k">Stocks tracked</span><span class="v">#{stocks}</span></div>
          <div class="stat"><span class="k">Combined market cap</span><span class="v">#{human_usd(total)}</span></div>
        </div>
      </div>
    </section>

    <main class="wrap">
    #{sections}
    </main>

    <footer>
      <div class="wrap">
        <p>Built with a single self-contained Elixir script • Data via Yahoo Finance • Updated daily by GitHub Actions</p>
        <p class="disclaimer">Market caps are estimates (converted to USD) for ranking and informational purposes only — not investment advice.</p>
      </div>
    </footer>
    </body>
    </html>
    """
  end

  defp market_section(m, i) do
    rows = m.rows |> Enum.map(&row_html(&1, m)) |> Enum.join("\n")
    mcap = m.rows |> Enum.map(& &1.mcap_usd) |> Enum.sum()

    """
    <section class="market" id="m#{i}">
      <div class="market-head">
        <h2>#{m.flag} #{e(m.name)}</h2>
        <div class="meta">#{e(m.country)} • #{human_usd(mcap)}</div>
      </div>
      <div class="table-scroll">
      <table>
        <thead>
          <tr><th class="r">#</th><th class="l">Company</th><th>Price</th><th>24h</th><th>Market Cap (USD)</th></tr>
        </thead>
        <tbody>
        #{rows}
        </tbody>
      </table>
      </div>
    </section>
    """
  end

  defp row_html(row, m) do
    """
    <tr>
      <td class="r rank">#{row.rank}</td>
      <td class="l name"><span class="tname">#{e(row.name)}</span><span class="tkr">#{e(row.ticker)}</span></td>
      <td class="num">#{price(row.price, m.currency)}</td>
      <td class="num">#{change_badge(row.change)}</td>
      <td class="num mcap">#{human_usd(row.mcap_usd)}</td>
    </tr>
    """
  end

  defp css do
    """
    :root{--bg:#f8fafd;--card:#fff;--text:#0d1421;--muted:#58667e;--line:#eff2f5;
      --green:#16c784;--red:#ea3943;--accent:#3861fb}
    *{box-sizing:border-box}
    body{margin:0;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;
      background:var(--bg);color:var(--text);font-size:14px;line-height:1.5}
    .wrap{max-width:1100px;margin:0 auto;padding:0 16px}
    .topbar{position:sticky;top:0;z-index:10;background:var(--card);border-bottom:1px solid var(--line)}
    .topbar .wrap{display:flex;align-items:center;gap:20px;height:60px}
    .brand{font-size:20px;font-weight:600;white-space:nowrap}
    .brand b{color:var(--accent)}
    .markets-nav{display:flex;gap:6px;overflow-x:auto;scrollbar-width:none}
    .markets-nav::-webkit-scrollbar{display:none}
    .markets-nav a{white-space:nowrap;color:var(--muted);text-decoration:none;font-size:12px;
      padding:6px 10px;border-radius:8px}
    .markets-nav a:hover{background:var(--bg);color:var(--text)}
    .hero{padding:40px 0 24px;text-align:center}
    .hero h1{margin:0 0 8px;font-size:30px}
    .hero .sub{margin:0 0 24px;color:var(--muted)}
    .stats{display:flex;justify-content:center;gap:14px;flex-wrap:wrap}
    .stat{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:14px 22px;min-width:150px}
    .stat .k{display:block;color:var(--muted);font-size:12px}
    .stat .v{display:block;font-size:22px;font-weight:700;margin-top:2px}
    .market{background:var(--card);border:1px solid var(--line);border-radius:14px;
      margin:18px 0;padding:6px 6px 10px;overflow:hidden}
    .market-head{display:flex;justify-content:space-between;align-items:baseline;
      flex-wrap:wrap;gap:6px;padding:14px 14px 6px}
    .market-head h2{margin:0;font-size:18px}
    .market-head .meta{color:var(--muted);font-size:13px}
    .table-scroll{overflow-x:auto}
    table{width:100%;border-collapse:collapse}
    th,td{padding:11px 14px;text-align:right;white-space:nowrap}
    th{color:var(--muted);font-size:12px;font-weight:500;border-bottom:1px solid var(--line)}
    th.l,td.l{text-align:left}
    th.r,td.r{text-align:center;width:40px}
    tbody tr{border-bottom:1px solid var(--line)}
    tbody tr:last-child{border-bottom:none}
    tbody tr:hover{background:var(--bg)}
    .rank{color:var(--muted);font-weight:600}
    .name .tname{font-weight:600;display:block}
    .name .tkr{color:var(--muted);font-size:12px;text-transform:uppercase}
    .num{font-variant-numeric:tabular-nums}
    .mcap{font-weight:600}
    .chg{font-weight:600}
    .chg.up{color:var(--green)} .chg.down{color:var(--red)} .chg.flat{color:var(--muted)}
    footer{padding:34px 0;text-align:center;color:var(--muted);font-size:12px}
    .disclaimer{opacity:.8;margin-top:6px}
    @media(max-width:640px){.hero h1{font-size:24px}.brand span{display:none}}
    """
  end
end

Stonk.build()
