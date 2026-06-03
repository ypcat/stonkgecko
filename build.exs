# stonkgecko — a single self-contained Elixir script that builds a static,
# CoinGecko-inspired stock tracker for the world's major stock markets.
#
#   * Home tab   — each market's top 10 by market cap
#   * Global tab — top 100 stocks across all markets, ranked by USD market cap
#   * Market tab — each market's top 100 by market cap
#
# Run with:  elixir build.exs   ->  writes public/index.html (+ favicon, CNAME)
#
# Data (no API key required): Yahoo Finance v7 quote endpoint (batched, with a
# cookie+crumb handshake) gives price + marketCap + change + name in one call.
# Market caps are converted to USD via live FX (chart endpoint) so markets are
# comparable. Tickers Yahoo doesn't recognize are dropped automatically, so the
# embedded candidate lists only need to be a superset — ranking is live.

Mix.install([{:req, "~> 0.5"}])

defmodule Stonk do
  @ua "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"
  @euronext_suffixes ~w(.PA .AS .BR .LS .IR .OL .MI)
  @cookie_urls ["https://fc.yahoo.com/", "https://finance.yahoo.com/"]
  @crumb_urls ["https://query1.finance.yahoo.com/v1/test/getcrumb", "https://query2.finance.yahoo.com/v1/test/getcrumb"]
  # Abort (without writing) below this many quotes, so a rate-limited runner
  # never overwrites the last good deploy with a sparse/empty page.
  @min_quotes 500

  # Markets in rough descending order of total capitalization. `suffix` drives
  # validation: "" = US (no dot), :euronext = any Euronext venue suffix,
  # otherwise the exact Yahoo suffix.
  def markets do
    [
      %{id: "nasdaq", name: "NASDAQ", country: "United States", flag: "🇺🇸", suffix: "", tickers: nasdaq()},
      %{id: "nyse", name: "NYSE", country: "United States", flag: "🇺🇸", suffix: "", tickers: nyse()},
      %{id: "euronext", name: "Euronext", country: "European Union", flag: "🇪🇺", suffix: :euronext, tickers: euronext()},
      %{id: "shanghai", name: "Shanghai (SSE)", country: "China", flag: "🇨🇳", suffix: ".SS", tickers: shanghai()},
      %{id: "tokyo", name: "Tokyo (JPX)", country: "Japan", flag: "🇯🇵", suffix: ".T", tickers: tokyo()},
      %{id: "india", name: "NSE India", country: "India", flag: "🇮🇳", suffix: ".NS", tickers: india()},
      %{id: "shenzhen", name: "Shenzhen (SZSE)", country: "China", flag: "🇨🇳", suffix: ".SZ", tickers: shenzhen()},
      %{id: "hongkong", name: "Hong Kong (HKEX)", country: "Hong Kong", flag: "🇭🇰", suffix: ".HK", tickers: hongkong()},
      %{id: "toronto", name: "Toronto (TSX)", country: "Canada", flag: "🇨🇦", suffix: ".TO", tickers: toronto()},
      %{id: "london", name: "London (LSE)", country: "United Kingdom", flag: "🇬🇧", suffix: ".L", tickers: london()},
      %{id: "saudi", name: "Tadawul", country: "Saudi Arabia", flag: "🇸🇦", suffix: ".SR", tickers: saudi()},
      %{id: "taiwan", name: "Taiwan (TWSE)", country: "Taiwan", flag: "🇹🇼", suffix: ".TW", tickers: taiwan()}
    ]
  end

  # ---- Candidate ticker universes (a superset; live data does the ranking) --

  defp nasdaq, do: ~w(NVDA AAPL MSFT GOOGL GOOG AMZN META AVGO TSLA NFLX COST PLTR ASML AMD CSCO PEP AZN TMUS LIN INTU QCOM TXN ISRG BKNG AMGN AMAT PDD ADBE HON GILD MU PANW ADP LRCX VRTX KLAC SBUX MELI INTC CRWD CMCSA CEG ADI MDLZ REGN APP PYPL SNPS CDNS MRVL FTNT ABNB WDAY CSX ORLY ADSK ROP NXPI CHTR AEP PCAR MNST PAYX CPRT KDP ROST DASH MAR FAST ODFL TTD EA VRSK CTAS DDOG XEL LULU EXC KHC CCEP GEHC IDXX TEAM BKR FANG MCHP CSGP DXCM AXON ZS WBD ANSS TTWO GFS ON CDW BIIB ILMN MDB WTW GEN NTAP FCNCA TER CTSH HOOD COIN SMCI ARM DLTR VRSN)

  defp nyse, do: ~w(BRK-B LLY WMT JPM V ORCL MA XOM UNH JNJ HD PG ABBV BAC CVX KO GE WFC CRM PM IBM UNP MS ABT GS MCD DIS AXP RTX CAT T MRK VZ NOW BX SCHW C PFE BLK SPGI BA WM TMO NEE LOW DE ELV COP BSX SYK UBER TJX MMC CB PGR MDT BMY CI DHR NKE SO DUK MO PNC CL ICE USB WELL APH CME GD ITW TT MCK EQIX CVS MMM COF EMR AON ZTS NOC FCX APD ECL GM LMT WMB PH CARR MSI BDX FDX SHW NSC SLB HCA D EOG TGT AJG MET TFC)

  defp euronext, do: ~w(MC.PA ASML.AS RMS.PA OR.PA TTE.PA PRX.AS SU.PA SAN.PA AIR.PA RACE.MI EL.PA AI.PA ENEL.MI DSY.PA ISP.MI CDI.PA ABI.BR BNP.PA INGA.AS EQNR.OL ENI.MI UCG.MI CS.PA SAF.PA DG.PA ADYEN.AS WKL.AS STLAM.MI KER.PA BN.PA DSFIR.AS EN.PA SGO.PA RI.PA GLE.PA PHIA.AS ACA.PA HEIA.AS G.MI BESI.AS LR.PA PUB.PA VIE.PA KBC.BR GBLB.BR MT.AS TEN.MI NEXI.MI ML.PA AKRBP.OL DNB.OL TEL.OL YAR.OL NHY.OL MOWI.OL CAP.PA STMPA.PA EDP.LS GALP.LS JMT.LS EDPR.LS NK.PA HO.PA RNO.PA ENGI.PA ORA.PA CA.PA GTT.PA EDEN.PA TEP.PA AC.PA SW.PA VIV.PA ERF.PA AMUN.PA SK.PA FR.PA AKE.PA ALO.PA UMG.AS AD.AS AGN.AS ASM.AS NN.AS AKZA.AS RAND.AS KPN.AS IMCD.AS SOLB.BR UCB.BR UMI.BR COLR.BR PROX.BR LOTB.BR AGS.BR SOF.BR WDP.BR ORK.OL SALM.OL KOG.OL GJF.OL TGS.OL SUBC.OL LDO.MI PST.MI PIRC.MI MB.MI BMED.MI REC.MI)

  defp shanghai, do: ~w(600519.SS 601398.SS 601288.SS 601939.SS 601857.SS 600941.SS 601988.SS 600036.SS 601628.SS 600900.SS 601318.SS 603288.SS 600276.SS 688981.SS 601888.SS 600030.SS 601166.SS 600028.SS 601088.SS 601658.SS 600887.SS 600809.SS 601012.SS 601668.SS 601816.SS 600438.SS 601138.SS 600406.SS 688041.SS 601225.SS 600585.SS 601633.SS 600690.SS 601728.SS 600050.SS 601601.SS 600031.SS 601919.SS 600104.SS 688111.SS 601066.SS 600436.SS 601985.SS 600089.SS 601390.SS 601186.SS 600196.SS 601800.SS 600309.SS 688012.SS 600009.SS 601995.SS 600600.SS 601877.SS 600346.SS 600905.SS 688256.SS 601169.SS 601211.SS 600848.SS 601618.SS 600999.SS 600183.SS 603259.SS 600745.SS 600588.SS 601336.SS 601111.SS 600150.SS 600426.SS 601319.SS 600547.SS 600188.SS 601898.SS 600795.SS 601229.SS 688599.SS 688008.SS 600025.SS 603501.SS 600518.SS 601377.SS 600660.SS 600754.SS 600570.SS 600352.SS 601865.SS 688036.SS 601989.SS 600061.SS 600886.SS 601021.SS 600015.SS 600016.SS 600837.SS 601881.SS 600340.SS 600018.SS 600011.SS 600219.SS 688561.SS 603986.SS 688271.SS 600875.SS 601238.SS 600362.SS)

  defp tokyo, do: ~w(7203.T 8306.T 6861.T 6758.T 9984.T 9983.T 8035.T 6098.T 9432.T 7974.T 8316.T 4063.T 9433.T 8058.T 6501.T 6902.T 8001.T 4502.T 8766.T 8031.T 7741.T 6594.T 6367.T 4519.T 7267.T 8411.T 6981.T 6273.T 4568.T 8053.T 7011.T 6857.T 4661.T 9434.T 6503.T 4543.T 7751.T 8002.T 6752.T 6954.T 4578.T 8801.T 6701.T 7269.T 4901.T 8267.T 9020.T 5108.T 8750.T 8591.T 7182.T 4503.T 6920.T 6146.T 6326.T 8802.T 6178.T 7733.T 6645.T 4452.T 2914.T 9022.T 5401.T 7201.T 7270.T 6502.T 6753.T 7832.T 4689.T 4307.T 8604.T 9613.T 3382.T 4684.T 4612.T 2802.T 6479.T 8630.T 8725.T 9101.T 5802.T 6504.T 7012.T 6723.T 6201.T 6471.T 5020.T 1605.T 9501.T 9531.T 9503.T 4188.T 4523.T 4528.T 3402.T 5713.T 2502.T 2503.T 4911.T 8113.T 9735.T 9202.T 9021.T 8830.T 7259.T 6963.T 6762.T 4151.T 9766.T)

  defp india, do: ~w(RELIANCE.NS HDFCBANK.NS TCS.NS BHARTIARTL.NS ICICIBANK.NS SBIN.NS INFY.NS LICI.NS BAJFINANCE.NS HINDUNILVR.NS ITC.NS LT.NS HCLTECH.NS KOTAKBANK.NS SUNPHARMA.NS MARUTI.NS AXISBANK.NS M&M.NS ULTRACEMCO.NS NTPC.NS BAJAJFINSV.NS TITAN.NS ONGC.NS ADANIENT.NS POWERGRID.NS ADANIPORTS.NS WIPRO.NS COALINDIA.NS BAJAJ-AUTO.NS NESTLEIND.NS ASIANPAINT.NS JSWSTEEL.NS TATAMOTORS.NS DMART.NS ADANIGREEN.NS ADANIPOWER.NS TATASTEEL.NS HINDZINC.NS HAL.NS TRENT.NS SIEMENS.NS VBL.NS BEL.NS ETERNAL.NS GRASIM.NS DLF.NS IOC.NS PIDILITIND.NS VEDL.NS INDIGO.NS DIVISLAB.NS BANKBARODA.NS AMBUJACEM.NS PNB.NS BPCL.NS GODREJCP.NS CIPLA.NS BRITANNIA.NS TVSMOTOR.NS EICHERMOT.NS HDFCLIFE.NS TATAPOWER.NS DRREDDY.NS SHRIRAMFIN.NS GAIL.NS LODHA.NS HAVELLS.NS TECHM.NS SBILIFE.NS MOTHERSON.NS TORNTPHARM.NS CHOLAFIN.NS JIOFIN.NS CGPOWER.NS DABUR.NS ZYDUSLIFE.NS MAXHEALTH.NS HEROMOTOCO.NS INDUSINDBK.NS BAJAJHLDNG.NS NAUKRI.NS BOSCHLTD.NS JSWENERGY.NS MANKIND.NS ICICIPRULI.NS UNITDSPR.NS CANBK.NS POLYCAB.NS INDHOTEL.NS SOLARINDS.NS ABB.NS SHREECEM.NS LTIM.NS GICRE.NS PFC.NS RECLTD.NS SWIGGY.NS NHPC.NS ICICIGI.NS TORNTPOWER.NS OFSS.NS BAJAJHFL.NS AUROPHARMA.NS BHEL.NS COLPAL.NS MUTHOOTFIN.NS LUPIN.NS NMDC.NS IRFC.NS PERSISTENT.NS MARICO.NS UNIONBANK.NS SUZLON.NS)

  defp shenzhen, do: ~w(300750.SZ 002594.SZ 000858.SZ 000333.SZ 300760.SZ 002475.SZ 000651.SZ 002415.SZ 000001.SZ 300059.SZ 002714.SZ 000568.SZ 002230.SZ 300124.SZ 000725.SZ 002241.SZ 300498.SZ 002304.SZ 000063.SZ 300274.SZ 002027.SZ 000338.SZ 002352.SZ 300015.SZ 002460.SZ 300014.SZ 002142.SZ 000538.SZ 002129.SZ 002311.SZ 300782.SZ 300450.SZ 002271.SZ 002050.SZ 000776.SZ 300033.SZ 002493.SZ 000625.SZ 300979.SZ 000792.SZ 002466.SZ 300661.SZ 000895.SZ 002624.SZ 002601.SZ 000938.SZ 002179.SZ 300751.SZ 300316.SZ 002709.SZ 300408.SZ 002648.SZ 000661.SZ 000100.SZ 002812.SZ 300346.SZ 002736.SZ 000166.SZ 300999.SZ 002384.SZ 300628.SZ 002920.SZ 300888.SZ 002074.SZ 300433.SZ 002032.SZ 300457.SZ 002916.SZ 300759.SZ 000596.SZ 002602.SZ 000877.SZ 002841.SZ 000301.SZ 002180.SZ 300677.SZ 300866.SZ 000999.SZ 002603.SZ 300253.SZ 300919.SZ 000708.SZ 002138.SZ 300223.SZ 002056.SZ 002508.SZ 002120.SZ 002353.SZ 300012.SZ 002340.SZ 002409.SZ 000423.SZ 300896.SZ 002007.SZ 300454.SZ 000768.SZ 002507.SZ 002013.SZ 000060.SZ 300630.SZ 002558.SZ 002572.SZ 000876.SZ 002146.SZ 300296.SZ 300413.SZ 300142.SZ 002405.SZ 000951.SZ)

  defp hongkong, do: ~w(0700.HK 9988.HK 1398.HK 0939.HK 0941.HK 1299.HK 3690.HK 0388.HK 3988.HK 1810.HK 2318.HK 0883.HK 1211.HK 0005.HK 9618.HK 0857.HK 0386.HK 2628.HK 1024.HK 2020.HK 0688.HK 3968.HK 0001.HK 0016.HK 0002.HK 0011.HK 0762.HK 0728.HK 2382.HK 2331.HK 6862.HK 9999.HK 9888.HK 9961.HK 2269.HK 1093.HK 1177.HK 6618.HK 6098.HK 2007.HK 0027.HK 0288.HK 0291.HK 0322.HK 0151.HK 2313.HK 1928.HK 0003.HK 0006.HK 0012.HK 0017.HK 0066.HK 0083.HK 0101.HK 0823.HK 1109.HK 1113.HK 0960.HK 2899.HK 3328.HK 1288.HK 6030.HK 6837.HK 1336.HK 2601.HK 0998.HK 1658.HK 0916.HK 0836.HK 0902.HK 1088.HK 1171.HK 0489.HK 0175.HK 2238.HK 2333.HK 9868.HK 2015.HK 9866.HK 0285.HK 0992.HK 0981.HK 1347.HK 0241.HK 1801.HK 2359.HK 6160.HK 1099.HK 0867.HK 2196.HK 1972.HK 0019.HK 1929.HK 3692.HK 2380.HK 0267.HK 1378.HK 0358.HK 1772.HK 3331.HK 0669.HK 9626.HK)

  defp toronto, do: ~w(RY.TO SHOP.TO TD.TO BN.TO ENB.TO AEM.TO CNR.TO BMO.TO CM.TO CP.TO BAM.TO CNQ.TO TRI.TO BNS.TO ATD.TO SU.TO TRP.TO MFC.TO BNRE.TO WCN.TO FNV.TO ABX.TO L.TO FTS.TO T.TO NTR.TO WPM.TO CSU.TO GIB-A.TO SLF.TO IFC.TO PPL.TO DOL.TO IMO.TO BCE.TO GWO.TO POW.TO NA.TO K.TO MRU.TO CVE.TO H.TO QSR.TO TECK-B.TO GFL.TO FM.TO MG.TO CCO.TO EMA.TO WN.TO OTEX.TO SAP.TO RCI-B.TO GIL.TO TOU.TO FFH.TO AQN.TO STN.TO WSP.TO DSG.TO PAAS.TO TIH.TO CTC-A.TO X.TO BIP-UN.TO BEP-UN.TO AC.TO CAE.TO CIGI.TO EFN.TO ARX.TO NGT.TO FSV.TO WFG.TO IVN.TO CCL-B.TO TFII.TO LUN.TO AGI.TO EQB.TO ONEX.TO DPM.TO EMP-A.TO BTO.TO CPX.TO BLX.TO PSK.TO KEY.TO NPI.TO OGC.TO SSRM.TO LNR.TO MEG.TO ERO.TO TPZ.TO PXT.TO BYD.TO ATZ.TO WDO.TO SES.TO CG.TO IGM.TO GRT-UN.TO REI-UN.TO CAR-UN.TO FCR-UN.TO CSH-UN.TO DOO.TO CLS.TO PRMW.TO HBM.TO WCP.TO VRN.TO)

  defp saudi, do: ~w(2222.SR 1120.SR 7010.SR 1180.SR 2010.SR 1150.SR 1010.SR 1060.SR 1211.SR 2280.SR 1020.SR 1030.SR 1050.SR 7020.SR 4002.SR 4013.SR 2020.SR 2350.SR 2380.SR 4190.SR 4030.SR 4001.SR 2310.SR 5110.SR 1080.SR 2290.SR 2001.SR 2330.SR 2060.SR 2040.SR 2050.SR 2270.SR 6001.SR 6010.SR 6004.SR 4003.SR 4008.SR 4050.SR 4061.SR 4240.SR 4031.SR 4040.SR 4200.SR 4280.SR 4321.SR 4338.SR 7200.SR 7203.SR 7202.SR 7204.SR 2082.SR 5120.SR 1182.SR 1183.SR 8210.SR 8010.SR 8012.SR 4142.SR 1212.SR 1214.SR 1320.SR 1301.SR 1304.SR 3010.SR 3020.SR 3030.SR 3040.SR 3050.SR 3060.SR 3080.SR 3090.SR 3091.SR 3001.SR 3002.SR 3003.SR 3004.SR 3005.SR 4250.SR 4300.SR 4020.SR 4090.SR 4100.SR 4150.SR 4220.SR 4160.SR 2080.SR 2081.SR 2110.SR 2130.SR 2150.SR 2160.SR 2180.SR 2370.SR)

  # London prices come back in pence (currency "GBp") but market cap in pounds.
  defp london, do: ~w(AZN.L SHEL.L HSBA.L ULVR.L BP.L RIO.L GSK.L REL.L DGE.L BATS.L GLEN.L LSEG.L RKT.L NG.L BARC.L LLOY.L CPG.L AAL.L PRU.L VOD.L TSCO.L NWG.L STAN.L BA.L HLN.L IMB.L SSE.L EXPN.L AV.L LGEN.L ABF.L SGRO.L ANTO.L SMT.L WTB.L III.L RTO.L INF.L SN.L CCH.L PSON.L WPP.L ITRK.L HLMA.L SMIN.L BNZL.L MNDI.L ADM.L PSN.L BKG.L LAND.L BLND.L SVT.L UU.L CNA.L SBRY.L KGF.L NXT.L JD.L BDEV.L TW.L DCC.L SPX.L CRDA.L RR.L AHT.L FRES.L ENT.L HIK.L SDR.L WEIR.L MRO.L DPLM.L AUTO.L RMV.L ICG.L PHNX.L BEZ.L BT-A.L SGE.L FCIT.L SMDS.L EDV.L GAW.L HSX.L BME.L HWDN.L IHG.L WG.L QQ.L ROR.L MNG.L OCDO.L TATE.L DLG.L FRAS.L CTEC.L BAB.L WIZZ.L EZJ.L ITV.L MKS.L PSH.L)

  defp taiwan, do: ~w(2330.TW 2317.TW 2454.TW 2308.TW 2382.TW 2891.TW 2412.TW 2881.TW 2882.TW 3711.TW 2303.TW 2886.TW 2884.TW 3045.TW 2357.TW 2885.TW 2880.TW 2892.TW 5880.TW 2883.TW 2887.TW 3008.TW 2002.TW 1303.TW 1301.TW 2395.TW 2890.TW 6505.TW 1216.TW 2207.TW 2603.TW 2327.TW 3034.TW 2379.TW 3231.TW 2345.TW 4938.TW 2912.TW 1326.TW 3037.TW 2301.TW 2409.TW 2474.TW 2376.TW 3661.TW 3017.TW 3702.TW 2354.TW 2356.TW 6669.TW 1101.TW 1102.TW 2618.TW 2610.TW 2615.TW 2609.TW 2888.TW 2889.TW 5871.TW 5876.TW 2801.TW 2809.TW 2823.TW 2834.TW 2105.TW 9910.TW 9904.TW 1402.TW 1476.TW 1590.TW 2049.TW 2360.TW 2377.TW 2383.TW 2451.TW 2458.TW 3023.TW 3035.TW 3036.TW 3443.TW 3533.TW 3653.TW 4904.TW 4958.TW 6415.TW 6446.TW 6488.TW 8046.TW 8454.TW 9921.TW 9945.TW 1227.TW 1210.TW 1229.TW 2106.TW 2371.TW 2353.TW 2347.TW 2352.TW 6239.TW 6147.TW 3532.TW 3406.TW 5269.TW 5347.TW 1605.TW 1609.TW 2204.TW 9914.TW 2027.TW)

  # ---- Ticker filtering ----------------------------------------------------

  defp valid_ticker?(t, ""), do: not String.contains?(t, ".")
  defp valid_ticker?(t, :euronext), do: String.ends_with?(t, @euronext_suffixes)
  defp valid_ticker?(t, suffix), do: String.ends_with?(t, suffix)

  # ---- Yahoo data fetching -------------------------------------------------

  def fetch_quotes(tickers, crumb, cookies) do
    tickers
    |> Enum.chunk_every(50)
    |> Enum.with_index()
    |> Enum.flat_map(fn {batch, i} ->
      if i > 0, do: Process.sleep(150)
      quote_batch(batch, crumb, cookies)
    end)
    |> Map.new()
  end

  defp quote_batch(batch, crumb, cookies) do
    url = "https://query1.finance.yahoo.com/v7/finance/quote"

    case Req.get(url,
           params: [symbols: Enum.join(batch, ","), crumb: crumb],
           headers: [{"user-agent", @ua}, {"cookie", cookies}],
           retry: :transient, max_retries: 3, receive_timeout: 25_000
         ) do
      {:ok, %{status: 200, body: %{"quoteResponse" => %{"result" => results}}}} ->
        for q <- results, is_number(q["marketCap"]) and q["marketCap"] > 0, is_number(q["regularMarketPrice"]) do
          {q["symbol"],
           %{
             price: q["regularMarketPrice"] * 1.0,
             mcap: q["marketCap"] * 1.0,
             change: numf(q["regularMarketChangePercent"]),
             currency: q["currency"] || "USD",
             name: q["longName"] || q["shortName"] || q["symbol"]
           }}
        end

      _ ->
        []
    end
  end

  # ---- Historical change (7d / 30d / 1y) -----------------------------------
  #
  # Yahoo's batched `spark` endpoint returns up to a year of daily closes per
  # symbol in a single call, from which the 7d/30d/1y percentage moves are
  # derived. It reuses the same crumb+cookie handshake as the quote endpoint.
  # Any failure degrades to nil (rendered as a neutral "·") rather than crashing.

  def fetch_history(tickers, crumb, cookies) do
    tickers
    |> Enum.chunk_every(50)
    |> Enum.with_index()
    |> Enum.flat_map(fn {batch, i} ->
      if i > 0, do: Process.sleep(150)
      spark_batch(batch, crumb, cookies)
    end)
    |> Map.new()
  end

  defp spark_batch(batch, crumb, cookies) do
    url = "https://query1.finance.yahoo.com/v7/finance/spark"

    case Req.get(url,
           params: [symbols: Enum.join(batch, ","), range: "1y", interval: "1d", crumb: crumb],
           headers: [{"user-agent", @ua}, {"cookie", cookies}],
           retry: :transient, max_retries: 3, receive_timeout: 25_000
         ) do
      {:ok, %{status: 200, body: %{"spark" => %{"result" => results}}}} when is_list(results) ->
        Enum.flat_map(results, &parse_spark_result/1)

      _ ->
        []
    end
  end

  defp parse_spark_result(%{"symbol" => sym, "response" => [resp | _]}) when is_map(resp) do
    ts = resp["timestamp"] || []

    closes =
      case get_in(resp, ["indicators", "quote"]) do
        [%{"close" => c} | _] when is_list(c) -> c
        _ -> []
      end

    [{sym, changes_from_series(ts, closes)}]
  end

  defp parse_spark_result(_), do: []

  # Pair up (timestamp, close), drop gaps/holidays, then read off the move from
  # the close nearest each lookback horizon to the most recent close.
  defp changes_from_series(ts, closes) when is_list(ts) and is_list(closes) do
    pairs =
      ts
      |> Enum.zip(closes)
      |> Enum.filter(fn {t, c} -> is_number(t) and is_number(c) and c > 0 end)

    case List.last(pairs) do
      {_t, last} ->
        %{
          d7: pct_change(price_near(pairs, 7), last),
          d30: pct_change(price_near(pairs, 30), last),
          d1y: pct_change(pairs |> List.first() |> elem(1), last)
        }

      nil ->
        %{d7: nil, d30: nil, d1y: nil}
    end
  end

  defp changes_from_series(_, _), do: %{d7: nil, d30: nil, d1y: nil}

  defp price_near(pairs, days_ago) do
    target = System.system_time(:second) - days_ago * 86_400

    pairs
    |> Enum.min_by(fn {t, _c} -> abs(t - target) end)
    |> elem(1)
  end

  defp pct_change(old, cur) when is_number(old) and is_number(cur) and old > 0,
    do: (cur - old) / old * 100

  defp pct_change(_, _), do: nil

  # Yahoo frequently rate-limits cloud/CI IPs, so retry the cookie+crumb dance
  # several times with backoff, trying both cookie sources and crumb hosts.
  defp crumb_handshake(attempt \\ 1)
  defp crumb_handshake(attempt) when attempt > 8, do: :error
  defp crumb_handshake(attempt) do
    case attempt_handshake() do
      {:ok, _, _} = ok ->
        ok

      :error ->
        if attempt == 1, do: IO.puts("  crumb handshake throttled, retrying...")
        Process.sleep(2000 * attempt)
        crumb_handshake(attempt + 1)
    end
  end

  defp attempt_handshake do
    Enum.reduce_while(@cookie_urls, :error, fn url, _ ->
      cookies =
        case Req.get(url, headers: [{"user-agent", @ua}], redirect: false, receive_timeout: 15_000) do
          {:ok, resp} -> collect_cookies(resp)
          _ -> ""
        end

      with true <- cookies != "",
           crumb when is_binary(crumb) <- fetch_crumb(cookies) do
        {:halt, {:ok, crumb, cookies}}
      else
        _ -> {:cont, :error}
      end
    end)
  end

  # A valid crumb is a short, space-free token; "Too Many Requests" / HTML
  # error bodies are rejected.
  defp fetch_crumb(cookies) do
    Enum.find_value(@crumb_urls, fn url ->
      case Req.get(url, headers: [{"user-agent", @ua}, {"cookie", cookies}], receive_timeout: 15_000) do
        {:ok, %{status: 200, body: b}} when is_binary(b) ->
          t = String.trim(b)
          if t != "" and byte_size(t) < 80 and not String.contains?(t, " "), do: t

        _ ->
          nil
      end
    end)
  end

  defp collect_cookies(%Req.Response{} = resp) do
    resp
    |> Req.Response.get_header("set-cookie")
    |> Enum.map(&(&1 |> String.split(";", parts: 2) |> hd()))
    |> Enum.join("; ")
  end

  # FX: 1 unit of `cur` -> USD via the chart endpoint (no crumb needed).
  def fx_rate("USD"), do: 1.0
  # London market caps are reported in pounds even though the quote currency is
  # "GBp" (pence), so both map to the GBP->USD rate.
  def fx_rate("GBp"), do: fx_rate("GBP")
  def fx_rate(cur) do
    url = "https://query1.finance.yahoo.com/v8/finance/chart/#{cur}USD=X"

    case Req.get(url, params: [interval: "1d", range: "5d"], headers: [{"user-agent", @ua}],
           retry: :transient, max_retries: 3, receive_timeout: 20_000) do
      {:ok, %{status: 200, body: %{"chart" => %{"result" => [r | _]}}}} ->
        numf(get_in(r, ["meta", "regularMarketPrice"]))

      _ ->
        nil
    end
  end

  defp numf(n) when is_number(n), do: n * 1.0
  defp numf(_), do: nil

  # ---- Assembly ------------------------------------------------------------

  def build do
    IO.puts("stonkgecko: building...")

    # Filter + uniq per market, then dedup globally so each Yahoo symbol is
    # assigned to a single market (first occurrence wins).
    {prepared, _} =
      Enum.map_reduce(markets(), MapSet.new(), fn m, seen ->
        tickers =
          m.tickers
          |> Enum.filter(&valid_ticker?(&1, m.suffix))
          |> Enum.uniq()
          |> Enum.reject(&MapSet.member?(seen, &1))

        {Map.put(m, :tickers, tickers), MapSet.union(seen, MapSet.new(tickers))}
      end)

    all = Enum.flat_map(prepared, & &1.tickers)
    IO.puts("  candidates: #{length(all)} tickers across #{length(prepared)} markets")

    {quotes, history} =
      case crumb_handshake() do
        {:ok, crumb, cookies} ->
          {fetch_quotes(all, crumb, cookies), fetch_history(all, crumb, cookies)}

        :error ->
          IO.puts("  ! crumb handshake failed — no market-cap data available")
          {%{}, %{}}
      end

    IO.puts("  quotes returned: #{map_size(quotes)}; history returned: #{map_size(history)}")

    if map_size(quotes) < @min_quotes do
      IO.puts("  SKIP: only #{map_size(quotes)} quotes (< #{@min_quotes}) — Yahoo throttled this runner. " <>
                "Writing nothing and exiting cleanly so the deploy is skipped and the last good site stays live.")
      System.halt(0)
    end

    currencies = quotes |> Map.values() |> Enum.map(& &1.currency) |> Enum.uniq()
    fx = Map.new(currencies, fn c -> {c, fx_rate(c)} end)
    IO.puts("  fx: #{inspect(fx)}")

    markets_data =
      prepared
      |> Enum.map(fn m ->
        rows =
          m.tickers
          |> Enum.map(fn t -> build_row(t, quotes[t], history[t], fx, m) end)
          |> Enum.reject(&is_nil/1)
          |> Enum.sort_by(& &1.mcap_usd, :desc)
          |> Enum.take(100)
          |> rank()

        total = Enum.sum(Enum.map(rows, & &1.mcap_usd))

        valid = Enum.reject(rows, fn r -> is_nil(r.change) end)
        weighted_denom = Enum.sum(Enum.map(valid, & &1.mcap_usd))

        total_change =
          if weighted_denom > 0 do
            Enum.sum(Enum.map(valid, fn r -> r.mcap_usd * r.change end)) / weighted_denom
          end

        m |> Map.put(:rows, rows) |> Map.put(:total, total) |> Map.put(:total_change, total_change)
      end)
      # Order markets by their tracked market cap (sum of top-100), not a hand-coded list.
      |> Enum.sort_by(& &1.total, :desc)
      |> Enum.with_index(1)
      |> Enum.map(fn {m, i} -> Map.put(m, :mrank, i) end)

    IO.puts("  market ranking: " <> Enum.map_join(markets_data, ", ", &"#{&1.mrank}.#{&1.name} #{Render.human_usd(&1.total)}"))

    global =
      markets_data
      |> Enum.flat_map(& &1.rows)
      |> Enum.sort_by(& &1.mcap_usd, :desc)
      |> Enum.take(100)
      |> rank()

    total = global |> Enum.map(& &1.mcap_usd) |> Enum.sum()
    tracked = markets_data |> Enum.flat_map(& &1.rows) |> length()
    IO.puts("  ranked #{tracked} stocks; global #1 = #{(List.first(global) || %{name: "—"}).name}")

    html = Render.page(markets_data, global, tracked, total)
    File.mkdir_p!("public")
    File.write!("public/index.html", html)
    File.write!("public/favicon.svg", Render.gecko_svg(true))
    File.write!("public/.nojekyll", "")
    File.write!("public/CNAME", "stonkgecko.com")
    IO.puts("stonkgecko: wrote public/index.html (#{byte_size(html)} bytes)")
  end

  defp build_row(_t, nil, _h, _fx, _m), do: nil
  defp build_row(t, q, h, fx, m) do
    rate = Map.get(fx, q.currency) || 1.0
    h = h || %{}

    %{
      ticker: t,
      name: q.name,
      flag: m.flag,
      market: m.name,
      currency: q.currency,
      price: q.price,
      change: q.change,
      d7: Map.get(h, :d7),
      d30: Map.get(h, :d30),
      d1y: Map.get(h, :d1y),
      mcap_usd: q.mcap * rate
    }
  end

  defp rank(rows), do: rows |> Enum.with_index(1) |> Enum.map(fn {r, i} -> Map.put(r, :rank, i) end)
end

defmodule Render do
  # ---- Formatting ----------------------------------------------------------

  def human_usd(n) when not is_number(n), do: "—"
  def human_usd(n) when n >= 1.0e12, do: "$#{f(n / 1.0e12)}T"
  def human_usd(n) when n >= 1.0e9, do: "$#{f(n / 1.0e9)}B"
  def human_usd(n) when n >= 1.0e6, do: "$#{f(n / 1.0e6)}M"
  def human_usd(n), do: "$#{f(n)}"

  defp f(x), do: :erlang.float_to_binary(x * 1.0, decimals: 2)

  @symbols %{"USD" => "$", "EUR" => "€", "JPY" => "¥", "CNY" => "¥", "HKD" => "HK$",
             "INR" => "₹", "CAD" => "C$", "SAR" => "ر.س ", "TWD" => "NT$", "NOK" => "kr ",
             "GBP" => "£", "GBp" => "p ", "DKK" => "kr ", "CHF" => "Fr ", "SGD" => "S$"}

  def price(p, "GBp"), do: "£#{:erlang.float_to_binary(p / 100, decimals: 2)}"
  def price(p, cur), do: "#{Map.get(@symbols, cur, "")}#{:erlang.float_to_binary(p * 1.0, decimals: 2)}"

  def change_badge(nil), do: ~s(<span class="chg flat">·</span>)
  def change_badge(c) do
    cls = if c >= 0, do: "up", else: "down"
    arrow = if c >= 0, do: "▲", else: "▼"
    ~s(<span class="chg #{cls}">#{arrow} #{:erlang.float_to_binary(abs(c) * 1.0, decimals: 2)}%</span>)
  end

  def e(s), do: s |> to_string() |> String.replace("&", "&amp;") |> String.replace("<", "&lt;") |> String.replace(">", "&gt;") |> String.replace("\"", "&quot;")

  # ---- Gecko mascot (also written out as favicon.svg) ----------------------

  def gecko_svg(standalone \\ false) do
    ns = if standalone, do: ~s( xmlns="http://www.w3.org/2000/svg"), else: ""

    """
    <svg#{ns} viewBox="0 0 64 64" width="100%" height="100%" role="img" aria-label="stonkgecko">
      <defs>
        <linearGradient id="gkbody" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stop-color="#7af7b0"/><stop offset="1" stop-color="#12b865"/>
        </linearGradient>
      </defs>
      <rect width="64" height="64" rx="16" fill="#0a1310"/>
      <path d="M30 41c-9 3-15-1-16-9-1-7 4-10 8-9" fill="none" stroke="url(#gkbody)" stroke-width="5.5" stroke-linecap="round"/>
      <path d="M27 43c5 5 13 5 20 0 7-5 8-15 2-21-6-6-17-5-22 2-3 5-2 9 1 13 2 3 1 5-1 7z" fill="url(#gkbody)"/>
      <g stroke="url(#gkbody)" stroke-width="4.6" stroke-linecap="round">
        <path d="M29 41l-4 8"/><path d="M45 46l3 8"/><path d="M51 26l9-3"/><path d="M43 17l3-9"/>
      </g>
      <circle cx="46" cy="25" r="3.6" fill="#0a1310"/><circle cx="47.3" cy="23.7" r="1.3" fill="#fff"/>
      <path d="M19 24c0-1 .8-1.8 1.8-1.8" fill="none" stroke="#bff7d6" stroke-width="1.6" stroke-linecap="round" opacity=".5"/>
    </svg>
    """
  end

  # ---- Page ----------------------------------------------------------------

  def page(markets, global, tracked, total) do
    updated = DateTime.utc_now() |> Calendar.strftime("%Y-%m-%d %H:%M UTC")

    tabs =
      [{"home", "Home"}, {"global", "Global"}] ++ Enum.map(markets, fn m -> {m.id, m.name} end)

    tabbar =
      tabs
      |> Enum.with_index()
      |> Enum.map(fn {{id, label}, i} ->
        active = if i == 0, do: " active", else: ""
        flag = case Enum.find(markets, &(&1.id == id)) do
          %{flag: fl} -> fl <> " "
          _ -> if id == "global", do: "🌐 ", else: if(id == "home", do: "🦎 ", else: "")
        end
        ~s(<button class="tab#{active}" data-tab="#{id}">#{flag}#{e(label)}</button>)
      end)
      |> Enum.join("")

    sections =
      [home_section(markets), global_section(global)] ++ Enum.map(markets, &market_section/1)
      |> Enum.join("\n")

    """
    <!doctype html>
    <html lang="en" data-theme="dark">
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>stonkgecko — World Stock Markets Ranked by Market Cap</title>
    <meta name="description" content="Track the world's top stock markets and their largest companies ranked by market capitalization. Top 100 stocks per exchange plus a global leaderboard, updated daily.">
    <meta name="keywords" content="stock market cap, largest companies, NYSE, NASDAQ, Euronext, Tokyo, Shanghai, Shenzhen, Hong Kong, NSE India, Toronto, Tadawul, Taiwan TWSE, stock ranking, market capitalization">
    <meta name="robots" content="index, follow">
    <link rel="canonical" href="https://stonkgecko.com/">
    <meta name="theme-color" content="#0a1310">
    <link rel="icon" href="/favicon.svg" type="image/svg+xml">
    <link rel="apple-touch-icon" href="/favicon.svg">
    <meta property="og:type" content="website">
    <meta property="og:url" content="https://stonkgecko.com/">
    <meta property="og:title" content="stonkgecko — World Stock Markets Ranked by Market Cap">
    <meta property="og:description" content="Top 100 companies per major exchange plus a global market-cap leaderboard. Updated daily.">
    <meta property="og:image" content="https://stonkgecko.com/favicon.svg">
    <meta name="twitter:card" content="summary">
    <meta name="twitter:title" content="stonkgecko — World Stock Markets Ranked by Market Cap">
    <meta name="twitter:description" content="Top 100 companies per major exchange plus a global market-cap leaderboard.">
    <meta name="twitter:image" content="https://stonkgecko.com/favicon.svg">
    <script type="application/ld+json">#{ld_json(tracked, total)}</script>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Bricolage+Grotesque:opsz,wght@12..96,500;12..96,700;12..96,800&family=Instrument+Sans:wght@400;500;600&family=JetBrains+Mono:wght@500;700&display=swap" rel="stylesheet">
    <script>(function(){try{var t=localStorage.getItem('sg-theme')||'dark';document.documentElement.setAttribute('data-theme',t);}catch(e){}})();</script>
    <style>#{css()}</style>
    </head>
    <body>
    <div class="grain"></div>
    <header class="topbar">
      <div class="wrap bar">
        <a class="brand" href="#" data-tab="home">
          <span class="logo">#{gecko_svg()}</span>
          <span class="word">stonk<b>gecko</b></span>
        </a>
        <button class="theme" id="theme" aria-label="Toggle theme"><span class="ti"></span></button>
      </div>
    </header>

    <section class="hero">
      <div class="wrap">
        <h1>The world's markets,<br><span class="hl">ranked by market cap.</span></h1>
        <p class="sub">Top 100 companies on each of the world's major exchanges, plus a global leaderboard — rebuilt every day.</p>
        <div class="stats">
          <div class="stat"><span class="v">#{length(markets)}</span><span class="k">Markets</span></div>
          <div class="stat"><span class="v">#{tracked}</span><span class="k">Stocks ranked</span></div>
          <div class="stat"><span class="v">#{human_usd(total)}</span><span class="k">Tracked market cap</span></div>
        </div>
      </div>
    </section>

    <nav class="tabbar"><div class="wrap tabwrap">#{tabbar}</div></nav>

    <div class="wrap searchwrap">
      <input id="search" type="search" placeholder="Filter the current tab by company or ticker…" autocomplete="off">
    </div>

    <main class="wrap">
    #{sections}
    </main>

    <footer>
      <div class="wrap">
        <div class="flogo">#{gecko_svg()}</div>
        <p>Built by a single self-contained Elixir script · Data via Yahoo Finance · Updated #{updated}</p>
        <p class="disc">Market caps are converted to USD for ranking and shown for informational purposes only — not investment advice.</p>
      </div>
    </footer>
    <script>#{js()}</script>
    </body>
    </html>
    """
  end

  defp ld_json(tracked, total) do
    ~s({"@context":"https://schema.org","@type":"WebSite","name":"stonkgecko",) <>
      ~s("url":"https://stonkgecko.com/",) <>
      ~s("description":"World stock markets ranked by market capitalization — #{tracked} companies, #{human_usd(total)} tracked.",) <>
      ~s("potentialAction":{"@type":"SearchAction","target":"https://stonkgecko.com/?q={search_term_string}","query-input":"required name=search_term_string"}})
  end

  # ---- Sections ------------------------------------------------------------

  defp home_section(markets) do
    cards =
      markets
      |> Enum.map(fn m ->
        rows =
          m.rows
          |> Enum.take(10)
          |> Enum.map(fn r ->
            """
            <tr>
              <td class="r rank">#{r.rank}</td>
              <td class="l name"><span class="tn">#{e(r.name)}</span><a class="tk" href="https://finance.yahoo.com/chart/#{URI.encode(r.ticker)}" target="_blank" rel="noopener">#{e(r.ticker)}</a></td>
              <td class="num pc"><span class="px">#{price(r.price, r.currency)}</span>#{change_badge(r.change)}</td>
              <td class="num mcap">#{human_usd(r.mcap_usd)}</td>
            </tr>
            """
          end)
          |> Enum.join("")

        """
        <div class="card">
          <button class="card-head" data-tab="#{m.id}">
            <span class="ch-l"><span class="ch-rank">#{m.mrank}</span><span class="ch-name">#{m.flag} #{e(m.name)}</span></span>
            <span class="ch-r"><span class="ch-cap">#{human_usd(m.total)}</span>#{change_badge(m.total_change)}</span>
          </button>
          <table class="mini">#{rows}</table>
        </div>
        """
      end)
      |> Enum.join("\n")

    ~s(<section class="tabpane active" id="pane-home"><div class="cards">#{cards}</div></section>)
  end

  defp global_section(global) do
    rows = global |> Enum.map(&row_html(&1, true)) |> Enum.join("\n")

    """
    <section class="tabpane" id="pane-global">
      <h2 class="pane-title">🌐 Global Top 100 <span>by market cap (USD)</span></h2>
      #{table(rows, true)}
    </section>
    """
  end

  defp market_section(m) do
    rows = m.rows |> Enum.map(&row_html(&1, false)) |> Enum.join("\n")
    mcap = m.rows |> Enum.map(& &1.mcap_usd) |> Enum.sum()

    """
    <section class="tabpane" id="pane-#{m.id}">
      <h2 class="pane-title">#{m.flag} #{e(m.name)} <span>#{e(m.country)} · #{human_usd(mcap)}</span></h2>
      #{table(rows, false)}
    </section>
    """
  end

  defp table(rows, global?) do
    src = if global?, do: ~s(<th class="l">Market</th>), else: ""

    """
    <div class="table-scroll">
    <table class="grid">
      <thead><tr>
        <th class="r">#</th><th class="l">Company</th>#{src}<th>Price</th><th>24h</th><th>7d</th><th>30d</th><th>1y</th><th>Market Cap</th>
      </tr></thead>
      <tbody>#{rows}</tbody>
    </table>
    </div>
    """
  end

  defp row_html(r, global?) do
    mkt = if global?, do: ~s(<td class="l mk">#{r.flag} <span>#{e(r.market)}</span></td>), else: ""

    """
    <tr>
      <td class="r rank">#{r.rank}</td>
      <td class="l name"><span class="tn">#{e(r.name)}</span><a class="tk" href="https://finance.yahoo.com/chart/#{URI.encode(r.ticker)}" target="_blank" rel="noopener">#{e(r.ticker)}</a></td>#{mkt}
      <td class="num">#{price(r.price, r.currency)}</td>
      <td class="num">#{change_badge(r.change)}</td>
      <td class="num">#{change_badge(r.d7)}</td>
      <td class="num">#{change_badge(r.d30)}</td>
      <td class="num">#{change_badge(r.d1y)}</td>
      <td class="num mcap">#{human_usd(r.mcap_usd)}</td>
    </tr>
    """
  end

  # ---- CSS -----------------------------------------------------------------

  defp css do
    """
    :root[data-theme="dark"]{
      --bg:#080f0c; --bg2:#0b1310; --surface:#0f1813; --surface2:#13201a; --hover:#16261e;
      --border:#1b2a22; --text:#e9f2ec; --muted:#7f988a; --faint:#56695e;
      --accent:#3ff08a; --accent2:#16d472; --up:#2fdc84; --down:#ff5f73;
      --glow:rgba(63,240,138,.18); --grain:.035;
    }
    :root[data-theme="light"]{
      --bg:#f2efe6; --bg2:#eae6d9; --surface:#fffdf7; --surface2:#f6f3ea; --hover:#efece1;
      --border:#e0dccd; --text:#10201a; --muted:#5e7066; --faint:#94a399;
      --accent:#0c9d57; --accent2:#0a8a4c; --up:#0c9d57; --down:#e03a4d;
      --glow:rgba(15,160,88,.10); --grain:.018;
    }
    *{box-sizing:border-box}
    html{scroll-behavior:smooth}
    body{margin:0;font-family:"Instrument Sans",-apple-system,sans-serif;background:var(--bg);
      color:var(--text);font-size:14.5px;line-height:1.5;-webkit-font-smoothing:antialiased;
      background-image:radial-gradient(60vw 50vh at 75% -5%,var(--glow),transparent 60%),
        radial-gradient(45vw 40vh at 5% 8%,var(--glow),transparent 55%);
      background-attachment:fixed;min-height:100vh}
    .grain{position:fixed;inset:0;pointer-events:none;z-index:1;opacity:var(--grain);
      background-image:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='120' height='120'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='.9' numOctaves='3'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)'/%3E%3C/svg%3E");mix-blend-mode:overlay}
    .wrap{max-width:1120px;margin:0 auto;padding:0 18px;position:relative;z-index:2}

    .topbar{position:sticky;top:0;z-index:30;backdrop-filter:blur(14px);
      background:color-mix(in srgb,var(--bg) 78%,transparent);border-bottom:1px solid var(--border)}
    .bar{display:flex;align-items:center;justify-content:space-between;height:62px}
    .brand{display:flex;align-items:center;gap:11px;text-decoration:none;color:var(--text)}
    .logo{width:38px;height:38px;display:block;filter:drop-shadow(0 3px 10px var(--glow))}
    .word{font-family:"Bricolage Grotesque",sans-serif;font-weight:700;font-size:22px;letter-spacing:-.02em}
    .word b{color:var(--accent);font-weight:800}
    .theme{width:40px;height:40px;border-radius:11px;border:1px solid var(--border);background:var(--surface);
      cursor:pointer;display:grid;place-items:center;transition:.2s}
    .theme:hover{border-color:var(--accent);background:var(--hover)}
    .ti{width:17px;height:17px;border-radius:50%;background:var(--accent);
      box-shadow:inset -5px -5px 0 0 var(--surface)}
    :root[data-theme="light"] .ti{box-shadow:none;background:var(--accent)}

    .hero{padding:64px 0 30px;text-align:center}
    .hero h1{font-family:"Bricolage Grotesque",sans-serif;font-weight:800;letter-spacing:-.035em;
      line-height:1.02;margin:0 0 16px;font-size:clamp(34px,6.4vw,62px)}
    .hero .hl{background:linear-gradient(100deg,var(--accent),var(--accent2));
      -webkit-background-clip:text;background-clip:text;color:transparent}
    .hero .sub{color:var(--muted);max-width:560px;margin:0 auto 30px;font-size:16px}
    .stats{display:flex;gap:14px;justify-content:center;flex-wrap:wrap}
    .stat{background:var(--surface);border:1px solid var(--border);border-radius:16px;
      padding:16px 26px;min-width:148px;text-align:left}
    .stat .v{display:block;font-family:"JetBrains Mono",monospace;font-weight:700;font-size:23px;color:var(--accent)}
    .stat .k{display:block;color:var(--muted);font-size:12px;margin-top:3px;text-transform:uppercase;letter-spacing:.06em}

    .tabbar{position:sticky;top:62px;z-index:20;background:color-mix(in srgb,var(--bg) 88%,transparent);
      backdrop-filter:blur(10px);border-bottom:1px solid var(--border);margin-top:18px}
    .tabwrap{display:flex;gap:6px;overflow-x:auto;padding:10px 18px;scrollbar-width:none}
    .tabwrap::-webkit-scrollbar{display:none}
    .tab{white-space:nowrap;border:1px solid transparent;background:transparent;color:var(--muted);
      font-family:"Instrument Sans",sans-serif;font-size:13.5px;font-weight:600;padding:8px 14px;
      border-radius:10px;cursor:pointer;transition:.15s}
    .tab:hover{color:var(--text);background:var(--surface)}
    .tab.active{color:var(--bg);background:var(--accent);border-color:var(--accent)}
    :root[data-theme="dark"] .tab.active{color:#06120c}

    .searchwrap{margin:22px auto 0}
    #search{width:100%;padding:13px 18px;border-radius:13px;border:1px solid var(--border);
      background:var(--surface);color:var(--text);font-size:14.5px;font-family:inherit;outline:none;transition:.2s}
    #search:focus{border-color:var(--accent);box-shadow:0 0 0 3px var(--glow)}
    #search::placeholder{color:var(--faint)}

    main{padding:18px 0 40px}
    .tabpane{display:none;animation:fade .25s ease}
    .tabpane.active{display:block}
    @keyframes fade{from{opacity:0;transform:translateY(6px)}to{opacity:1;transform:none}}

    .pane-title{font-family:"Bricolage Grotesque",sans-serif;font-weight:700;font-size:24px;
      letter-spacing:-.02em;margin:6px 4px 14px;display:flex;align-items:baseline;gap:12px;flex-wrap:wrap}
    .pane-title span{font-family:"Instrument Sans";font-size:14px;font-weight:500;color:var(--muted)}

    .table-scroll{overflow-x:auto;border:1px solid var(--border);border-radius:16px;background:var(--surface)}
    table.grid{width:100%;border-collapse:collapse;min-width:820px}
    .grid th,.grid td{padding:13px 16px;text-align:right;white-space:nowrap}
    .grid th{position:sticky;top:0;background:var(--surface2);color:var(--muted);font-size:11.5px;
      font-weight:600;text-transform:uppercase;letter-spacing:.05em;border-bottom:1px solid var(--border);z-index:1}
    .grid th.l,.grid td.l{text-align:left}
    .grid th.r,.grid td.r{text-align:center;width:54px}
    .grid tbody tr{border-bottom:1px solid var(--border)}
    .grid tbody tr:last-child{border-bottom:none}
    .grid tbody tr:hover{background:var(--hover)}
    .rank{font-family:"JetBrains Mono",monospace;color:var(--faint);font-weight:700;font-size:13px}
    .name{max-width:280px}
    .name .tn{font-weight:600;display:block;overflow:hidden;text-overflow:ellipsis}
    .name a.tk{display:block;color:var(--muted);font-size:11.5px;font-family:"JetBrains Mono",monospace;text-decoration:none}
    .name a.tk:hover{color:var(--accent);text-decoration:underline}
    .mk{color:var(--muted);font-size:12.5px}.mk span{vertical-align:middle}
    .num{font-family:"JetBrains Mono",monospace;font-size:13px}
    .mcap{font-weight:700;color:var(--text)}
    .chg{font-weight:700;font-size:12.5px}
    .chg.up{color:var(--up)} .chg.down{color:var(--down)} .chg.flat{color:var(--faint)}

    .cards{display:grid;grid-template-columns:repeat(auto-fill,minmax(330px,1fr));gap:16px}
    .card{background:var(--surface);border:1px solid var(--border);border-radius:18px;overflow:hidden;
      transition:.2s}
    .card:hover{border-color:var(--accent);transform:translateY(-2px)}
    .card-head{width:100%;display:flex;align-items:center;justify-content:space-between;gap:10px;
      padding:13px 15px;background:var(--surface2);border:none;border-bottom:1px solid var(--border);
      cursor:pointer;color:var(--text);text-align:left}
    .ch-l{display:flex;align-items:center;gap:10px;min-width:0}
    .ch-rank{flex:none;display:grid;place-items:center;width:24px;height:24px;border-radius:8px;
      background:var(--accent);color:#06120c;font-family:"JetBrains Mono",monospace;font-weight:700;font-size:12px}
    :root[data-theme="light"] .ch-rank{color:#fff}
    .ch-name{font-family:"Bricolage Grotesque",sans-serif;font-weight:700;font-size:15px;
      overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
    .ch-r{flex:none;display:flex;flex-direction:column;align-items:flex-end;line-height:1.25}
    .ch-cap{font-family:"JetBrains Mono",monospace;font-weight:700;font-size:13.5px;color:var(--text)}
    .ch-go{color:var(--accent);font-family:"Instrument Sans";font-size:11.5px;font-weight:600}
    table.mini{width:100%;border-collapse:collapse}
    .mini td{padding:8px 12px;border-bottom:1px solid var(--border)}
    .mini tr:last-child td{border-bottom:none}
    .mini tr:hover{background:var(--hover)}
    .mini .r{width:22px;text-align:center;padding:8px 2px 8px 13px}
    .mini td.name{width:100%;max-width:0;padding-left:6px}
    .mini .num{text-align:right;white-space:nowrap}
    .mini .pc{width:1%}
    .mini .pc .px{display:block;font-family:"JetBrains Mono",monospace;font-size:12.5px}
    .mini .pc .chg{display:block;font-size:11px;line-height:1.2}
    .mini .mcap{width:1%;padding-right:13px}

    footer{border-top:1px solid var(--border);padding:38px 0;text-align:center;color:var(--muted);font-size:12.5px}
    .flogo{width:34px;height:34px;margin:0 auto 12px;opacity:.85}
    .disc{color:var(--faint);margin-top:6px;font-size:11.5px}
    @media(max-width:560px){.hero{padding:42px 0 22px}.word{font-size:19px}.stat{min-width:120px;padding:13px 18px}}
    """
  end

  # ---- JS ------------------------------------------------------------------

  defp js do
    """
    (function(){
      var tabs=document.querySelectorAll('[data-tab]');
      var panes=document.querySelectorAll('.tabpane');
      var btns=document.querySelectorAll('.tab');
      var search=document.getElementById('search');
      function show(id){
        panes.forEach(function(p){p.classList.toggle('active',p.id==='pane-'+id)});
        btns.forEach(function(b){b.classList.toggle('active',b.dataset.tab===id)});
        if(search){search.value='';filter('')}
        window.scrollTo({top:document.querySelector('.tabbar').offsetTop-70,behavior:'smooth'});
      }
      tabs.forEach(function(t){t.addEventListener('click',function(e){e.preventDefault();show(t.dataset.tab)})});
      function filter(q){
        q=q.toLowerCase();
        var pane=document.querySelector('.tabpane.active');
        if(!pane)return;
        pane.querySelectorAll('tbody tr, .mini tr').forEach(function(tr){
          tr.style.display = !q || tr.textContent.toLowerCase().indexOf(q)>-1 ? '' : 'none';
        });
      }
      if(search)search.addEventListener('input',function(){filter(search.value)});
      var theme=document.getElementById('theme');
      theme.addEventListener('click',function(){
        var cur=document.documentElement.getAttribute('data-theme')==='dark'?'light':'dark';
        document.documentElement.setAttribute('data-theme',cur);
        try{localStorage.setItem('sg-theme',cur)}catch(e){}
      });
    })();
    """
  end
end

Stonk.build()
