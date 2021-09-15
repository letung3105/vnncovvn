using Dates, DataFrames
import CSV, HTTP

DATASETS_ROOT = "datasets"
TIMESERIES_URL = "https://vnexpress.net/microservice/sheet/type/covid19_2021_by_day"
TIMESERIES_FILE = joinpath(DATASETS_ROOT, "vnexpress_covid19_timeseries_vn.csv")
TIMESERIES_CUTOFF_DATE = today()

res = HTTP.get(TIMESERIES_URL)
df = CSV.read(res.body, DataFrame)

# get necessary columns
select!(
    df,
    "day_full" => (x -> Date.(x, dateformat"Y/m/d")) => :date,
    "new_cases" => :confirmed_per_day,
    "total_cases" => :confirmed_total,
    "new_deaths" => :deaths_per_day,
    "total_deaths" => :deaths_total,
    "new_recovered" => :recovered_per_day,
    "total_recovered_12" => :recovered_total,
)
filter!(:date => d -> d < TIMESERIES_CUTOFF_DATE, df)
sort!(df, :date)
transform!(df,
    [:confirmed_total, :deaths_total, :recovered_total]
        => ((x, y, z) -> x - y - z)
        => :currently_infected
)

if !isdir(DATASETS_ROOT)
    mkdir(DATASETS_ROOT)
end
CSV.write(TIMESERIES_FILE, df)