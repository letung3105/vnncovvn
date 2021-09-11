### A Pluto.jl notebook ###
# v0.15.1

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : missing
        el
    end
end

# ╔═╡ 48463954-2d4b-46fa-81ad-3e3c52420702
begin
	import Pkg
	Pkg.activate(pwd())
	Pkg.add([
			"PlutoUI", "HTTP", "CSV", "DataFrames", 
			"Impute", "Plots", "StatsPlots", "CategoricalArrays",
			])
	
	using Dates, PlutoUI, DataFrames, Impute, Plots, StatsPlots, CategoricalArrays
	import LinearAlgebra, HTTP, CSV
	
	gr()
	Plots.GRBackend()
	Plots.default(
		legend = :topleft,
		minorgrid = true,
		linecolor = :match,
		color_palette = :seaborn_deep,
		size = (700, 400),
	)
	
	PALETTE_COLORS = palette(:seaborn_deep)
end;

# ╔═╡ 52c5aa3b-31c9-41d6-b840-b766d8724932
md"## Plots"

# ╔═╡ 57eb35c4-c1e4-44d9-9d67-e085361bbfb4
md"### Cases progression"

# ╔═╡ fc216607-af60-431a-bac5-53240596b6a9
md"#### By location"

# ╔═╡ 873db3d5-af35-4d03-b4ff-5a1f10ab4924
md"##### Select locations for comparison"

# ╔═╡ 5dcca0d1-aabe-4512-a322-5e9fa3ebdb28
md"### Vaccination progression"

# ╔═╡ 70584069-db75-4f6b-aa0d-43de20a36ed8
md"## References"

# ╔═╡ 87d376c4-074c-11ec-3a91-27b12d84faef
SEEDS = Dict(
	:vnexpress => [
		"https://vnexpress.net/microservice/sheet/type/covid19_2021_by_total",
		"https://vnexpress.net/microservice/sheet/type/covid19_2021_by_location",
		"https://vnexpress.net/microservice/sheet/type/covid19_2021_by_day",
		"https://vnexpress.net/microservice/sheet/type/vaccine_data_vietnam",
		"https://vnexpress.net/microservice/sheet/type/vaccine_data_vietnam_city",
		"https://vnexpress.net/microservice/sheet/type/vaccine_to_vietnam",
		
		# Not using
		"https://vnexpress.net/microservice/sheet/type/covid19_2021_by_map",
		"https://vnexpress.net/microservice/sheet/type/covid19_2021_281",
		
		# This one is JSON and it's not important parsing this
		"https://vnexpress.net/microservice/sheet/type/vaccine_covid_19",
		
		# Contains the same data as vaccine_data_vietnam_city
		"https://vnexpress.net/microservice/sheet/type/vaccine_data_map",
	]
)

# ╔═╡ 4df3b761-c69a-4b96-81dc-08177d044447
md"## Glossary"

# ╔═╡ 2f303728-e590-4b45-8e89-53b48f9ef242
md"### Data retrievals"

# ╔═╡ 88e4d0b5-7024-45e4-b867-6da55f726d17
DATAFRAMES_RAW = Dict(asyncmap(collect(keys(SEEDS))) do srcname
	srcname => Dict(asyncmap(SEEDS[srcname]) do url
		r = HTTP.get(url)
		df = CSV.read(r.body, DataFrame)
		dfname = Symbol(last(split(url, c -> c == '/')))
		dfname => df
		end)
	end)

# ╔═╡ 06f0d4dc-25a2-4b3f-8558-d0b4935f7e99
LOCATIONS = sort!(names(DATAFRAMES_RAW[:vnexpress][:covid19_2021_by_location])[2:63])

# ╔═╡ fd11d312-8082-4faf-9551-dc597687f4ef
@bind locs_to_plot_binding MultiCheckBox(LOCATIONS)

# ╔═╡ f14c4beb-9803-40c3-8142-fd80e1cc96a2
begin
	locs_to_plot = []
	if !isnothing(locs_to_plot_binding)
		append!(locs_to_plot, [Symbol(loc) for loc in locs_to_plot_binding])
	end
end;

# ╔═╡ d9dabd88-5e88-4b94-816e-3545f598100b
DATES = Date(2021, 4, 27):Dates.Day(1):Dates.today()

# ╔═╡ 1ecf716e-a584-4013-852b-2f461f63fe66
let checkbox_plot_log = @bind overview_plot_log_y CheckBox();
	date_plot_begin = @bind overview_plot_date_begin DateField(DateTime(DATES[1]));
	date_plot_end = @bind overview_plot_date_end DateField(DateTime(DATES[end]))
	
	md"Plot from $date_plot_begin to $date_plot_end. Log scale? $checkbox_plot_log"
end

# ╔═╡ 923f6fc4-02d0-41e0-92a8-27192c4c7137
let date_plot_begin = 
		@bind compositions_plot_date_begin DateField(DateTime(DATES[1]));
	date_plot_end =
		@bind compositions_plot_date_end DateField(DateTime(DATES[end]))
	
	md"Plot from $date_plot_begin to $date_plot_end"
end

# ╔═╡ 8d1e5acb-996e-4edf-abd8-97eced94b3d0
let checkbox_plot_log = @bind status_plot_log_y CheckBox();
	date_plot_begin = @bind status_plot_date_begin DateField(DateTime(DATES[1]));
	date_plot_end = @bind status_plot_date_end DateField(DateTime(DATES[end]))
	
	md"Plot from $date_plot_begin to $date_plot_end. $checkbox_plot_log Log scale (not apply for active cases differences)."
end

# ╔═╡ 1acb67e9-1a36-447d-a5a7-f5aba52d53d7
let checkbox_plot_log = @bind top8_locs_plot_log_y CheckBox();
	date_plot_begin = @bind top8_locs_plot_date_begin DateField(DateTime(DATES[1]));
	date_plot_end = @bind top8_locs_plot_date_end DateField(DateTime(DATES[end]))
	
	md"Plot from $date_plot_begin to $date_plot_end. Log scale? $checkbox_plot_log"
end

# ╔═╡ 8ace2145-8521-45a9-83b1-ab8f6eadfaea
let checkbox_plot_log = @bind compare_locs_plot_log_y CheckBox();
	date_plot_begin = @bind compare_locs_plot_date_begin DateField(DateTime(DATES[1]));
	date_plot_end = @bind compare_locs_plot_date_end DateField(DateTime(DATES[end]))
	
	md"Plot from $date_plot_begin to $date_plot_end. Log scale? $checkbox_plot_log"
end

# ╔═╡ 6f441a7a-97b8-4db3-84fa-34dc8971b8f8
VACCINE_TYPES = let df = select(
		DATAFRAMES_RAW[:vnexpress][:vaccine_to_vietnam],
		"Loại Vaccine");
	
	filter!(x -> !ismissing(x["Loại Vaccine"]), df)
	[filter(x -> !isspace(x), vax_type) for vax_type in df[:, "Loại Vaccine"]]
end

# ╔═╡ 687209a9-a2ef-46af-99a7-571abf5e90c8
POPULATION_VN =
let df = select(
		DATAFRAMES_RAW[:vnexpress][:vaccine_data_vietnam_city],
		"Tỉnh thành Crawl" => :location,
		"Tổng số dân" => :population,
		"Tổng số dân trên 18 tuổi" => :population_over_18,
		"Số liều Vaccine dự kiến phân bổ" => :expected_doses)
	coalesce.(df, 0)
end

# ╔═╡ bcc7b16f-9714-45e9-92bd-70dbea4b4cc6
md"### Cleaned dataframes"

# ╔═╡ ab548612-82a5-48fa-b81c-aae646666997
md"### Packages"

# ╔═╡ 85665111-9c21-457d-b4c2-d12521761522
md"### Helper functions"

# ╔═╡ 4b600132-f50e-4aaf-9646-a2bc4d643634
hasmissing(df::DataFrame) =
	any(Iterators.flatten(map(row -> ismissing.(values(row)), eachrow(df))))

# ╔═╡ 7b9759f1-f696-4d50-822d-88df713fb575
begin
	# Copy of AreaPlot
	@userplot MyAreaPlot

	# This is modified to work with log scaling on yaxis,
	# :fillrange runs down to 1 instead of 0
	@recipe function f(a::MyAreaPlot)
		data = cumsum(a.args[end], dims = 2)
		x = length(a.args) == 1 ? (axes(data, 1)) : a.args[1]
		seriestype := :line
		for i in axes(data, 2)
			@series begin
				fillrange := i > 1 ? data[:, i - 1] : 1
				x, data[:, i]
			end
		end
	end
end

# ╔═╡ dede2946-ee8b-4a78-b9a6-e7e51eeeb41f
function clean_covid19_2021_by_day(df_raw::DataFrame)::DataFrame
	df = copy(df_raw)
	# Rename columns and parse date column
	select!(
		df,
		"day_full" => (x -> Date.(x, dateformat"Y/m/d")) => :date,
		# All daily cases
		"new_cases" => :cases,
		# Daily active cases
		"new_active" => :cases_active,
		# Daily cases within the community
		"CỘNG ĐỒNG" => :cases_community,
		"blockade" => :cases_quarantined,
		"community" => :cases_investigating,
		# Daily cases from immigrants
		"imported" => :cases_imported,
		# All cummulative cases (since 27/04)
		"total_cases" => :cases_cummulative,
		# Cummulative active cases
		"total_active" => :cases_cummulative_active,
		# Cummulative cases within the community
		"TỔNG CỘNG ĐỒNG" => :cases_cummulative_community,
		# Cummulative cases with severe conditions 
		"ECMO" => :cases_cummulative_on_ecmo,
		"ICU_52" => :cases_cummulative_on_icu,
		# Daily deaths
		"new_deaths" => :deaths,
		# Cummulative deaths
		"total_deaths" => :deaths_cummulative,
		# Daily recovered
		"new_recovered" => :recovered,
		# Cummulative recovered
		"total_recovered_12" => :recovered_cummulative,
	)
	
	# Collect data within valid dates
	filter!(cols -> cols.date in DATES, df)
	
	# Replace missing cases under investigation with total number of cases
	# in the community. This is done because in earlier dates, there's no
	# report on this particular number.
	df[!, "cases_investigating"] = 
		coalesce.(df[!, :cases_investigating], df[!, :cases_community])
	
	# Replace missing cases in quarantine with 0, because we already assume
	# all community cases are not quarantined in dates with missing data
	df[!, "cases_quarantined"] = 
	 	coalesce.(df[!, :cases_quarantined], 0)
	
	# Use Last Observered Carried Forward replacement strategy for cases
	# on ECMO and ICU, while setting the initial number to 0.
	cols_cumulative_locf = [:cases_cummulative_on_ecmo, :cases_cummulative_on_icu]
	df[1, cols_cumulative_locf[1]] = 0
	df[1, cols_cumulative_locf[2]] = 0
	df[!, cols_cumulative_locf] = Impute.locf(df[!, cols_cumulative_locf])
	
	@assert !hasmissing(df)
	
	# Adding new columns
	transform!(df,
		# Calculate mortality
		[:deaths_cummulative, :cases_cummulative]
		=> ((deaths, cases) -> deaths.//cases.*100)
		=> :mortality,
		
		# Normalized daily cases under investigation 
		[:cases, :cases_quarantined, :cases_imported]
		=> ((x, y, z) -> 1 .- y.//(x .+ 1) .- z.//(x .+ 1))
		=> :cases_investigating_weight,
		# Normalized daily cases under quarantine
		[:cases, :cases_quarantined]
		=> ((x, y) -> y .// (x .+ 1))
		=> :cases_quarantined_weight,
		# Normalized daily cases from immigrants
		[:cases, :cases_imported]
		=> ((x, y) -> y .// (x .+ 1))
		=> :cases_imported_weight,
		
		# Normalized cummulative active cases over cummulative cases
		[:cases_cummulative, :deaths_cummulative, :recovered_cummulative]
		=> ((x, y, z) -> 1 .- y.//x .- z.//x)
		=> :cases_cummulative_active_weight,
		# Normalized cummulative deaths over cummulative cases
		[:cases_cummulative, :deaths_cummulative]
		=> ((x, y) -> y .// x)
		=> :deaths_cummulative_weight,
		# Normalized cummulative recovered cases over cummulative cases
		[:cases_cummulative, :recovered_cummulative]
		=> ((x, y) -> y .// x)
		=> :recovered_cummulative_weight,
		
		# Calculate percentage of cases that are on ICU
		[:cases_cummulative_on_icu, :cases_cummulative]
		=> ((x, y) -> x .// y .* 100)
		=> :cases_cummulative_on_icu_percent,
		# Calculate percentage of cases that are on ECMO
		[:cases_cummulative_on_ecmo, :cases_cummulative]
		=> ((x, y) -> x .// y .* 100)
		=> :cases_cummulative_on_ecmo_percent,
	)
	
	df
end

# ╔═╡ 0b642ad0-8648-41bd-8d75-062a50a0e0e3
function clean_covid19_2021_by_total(df_raw::DataFrame)::DataFrame
	df = copy(df_raw)
	
	# Remove the first row that has missing date
	delete!(df, 1)
	
	# Convert string to date and only select needed columns
	select!(df,
		"Ngày" => (x -> Date.(x .* "/2021", dateformat"d/m/Y")) => :date,
		LOCATIONS
	)
	
	# Should be no missing field
	@assert !hasmissing(df)
	df
end

# ╔═╡ ed4ebadd-adb7-4c97-a044-48fcc37064b8
function clean_covid19_2021_by_location(df_raw::DataFrame)::DataFrame
	df = copy(df_raw)
	
	# Remove the first row that has missing date
	delete!(df, 1)
	
	# Convert string to date and only select needed columns
	select!(df,
		"Ngày" => (x -> Date.(x .* "/2021", dateformat"d/m/Y")) => :date,
		LOCATIONS
	)
	
	# Replace missing with 0
	df = coalesce.(df, 0)
	
	# Should be no missing field
	@assert !hasmissing(df)
	df
end

# ╔═╡ 1f807f44-8481-4ec1-86ae-e0cdbdfc03be
function clean_vaccine_to_vietnam(df_raw::DataFrame)::DataFrame
	df = copy(df_raw)
	# remove spacing from name for easy access
	rename!(df, "Sputnik V" => :SputnikV)
	
	df = select!(df,
		"Ngày" => :date,
		"Số liều đã về" => :total,
		Cols(VACCINE_TYPES))
	
	# first row contains null date
	delete!(df, 1)
	
	# parse string as date type
	df[!, :date] = Date.(df[!, :date] .* "/2021", dateformat"d/m/Y")
	
	# replace missing with "0"
	df = coalesce.(df, "0")
	
	# parse every column accep "date" and "Sputnik V" as Int
	let selector = Not([:date, :SputnikV])
		df[!, selector] = parse.(Int, filter.(isdigit, df[!, selector]))
	end
	
	# fill date for "Sputnik V" by subtracting total with sum of others
	# we do this because "Sputnik V" column contains incorrect data
	let selector = Not([:date, :total, :SputnikV])
		df[!, :SputnikV] = df[!, :total] - sum.(eachrow(df[!, selector]))
	end
	
	# create data for missing dates
	df_dates = DataFrame(date=DATES)
	df_series = coalesce.(sort(outerjoin(df_dates, df, on = :date), :date), 0)
	
	# create cummulative sum of doses received 
	let cols = names(df_series, Not(:date))
		transform!(df_series, cols .=> cumsum)
	end
	filter!(x -> x.date in DATES, df_series)
	
	@assert !hasmissing(df)
	df_series
end

# ╔═╡ c484ef80-eb8d-44be-929c-9e0085ce2f79
function clean_vaccine_to_vietnam_expect(df_raw::DataFrame)::DataFrame
	df = select(df_raw, "Loại Vaccine" => :name, "Số liều theo loại" => :doses)
	# remove row with missing name
	filter!(x -> !ismissing(x.name), df)
	# replace all missing with "0"
	df = coalesce.(df, "0")
	# parse string as number
	transform!(
		df,
		:doses => (x -> parse.(Int, filter.(isdigit, x)));
		renamecols=false)
	
	@assert !hasmissing(df)
	df
end

# ╔═╡ 23f785a7-e6d4-45d8-bc2e-584a915756cb
function clean_vaccine_data_vietnam(df_raw::DataFrame)::DataFrame
	df = select(df_raw,
		"Ngày" => :date,
		"Tổng số mũi đã tiêm" => :doses_given,
				
		"Tổng số người đã tiêm" => :vaxed_cumsum,
		"Tổng số người đã tiêm theo ngày" => :vaxed,
		
		"Số người tiêm đủ mũi" => :vaxed_fully_cumsum,
		"Số người tiêm đủ mũi theo ngày" => :vaxed_fully,
		
		"Số người tiêm chưa đủ mũi" => :vaxed_partly_cumsum,
		"Số người tiêm chưa đủ mũi theo ngày" => :vaxed_partly)
	
	# parse string as date type
	df[!, :date] = Date.(df[!, :date] .* "/2021", dateformat"d/m/Y")
	filter!(x -> x.date in DATES, df)
	
	# set missing daily number to 0
	let selector = [:doses_given, :vaxed, :vaxed_fully, :vaxed_partly]
		df[!, selector] = coalesce.(df[!, selector], 0)
	end
	
	# replace missing with last-observered-carried-forward stategy
	let selector = [:vaxed_cumsum, :vaxed_fully_cumsum, :vaxed_partly_cumsum]
		Impute.locf!(df[!, selector])
	end
	
	# number of vaccinated weighted over population total
	total_pop_vn = sum(POPULATION_VN[!, :population])
	transform!(df,
		:vaxed_partly_cumsum
		=> (x -> x .// total_pop_vn)
		=> :vaxed_partly_cumsum_weight,
			
		:vaxed_fully_cumsum
		=> (x -> x .// total_pop_vn)
		=> :vaxed_fully_cumsum_weight)
	
	@assert !hasmissing(df)
	df
end

# ╔═╡ f8b80935-e3fc-4224-82a9-adf88c3bcc97
DATAFRAMES = Dict(
	:vnexpress_covid19_2021_by_day
	=> clean_covid19_2021_by_day(
		DATAFRAMES_RAW[:vnexpress][:covid19_2021_by_day]),
		
	:vnexpress_covid19_2021_by_location
	=> clean_covid19_2021_by_location(
		DATAFRAMES_RAW[:vnexpress][:covid19_2021_by_location]),
		
	:vnexpress_covid19_2021_by_location_cumsum
	=> clean_covid19_2021_by_total(
		DATAFRAMES_RAW[:vnexpress][:covid19_2021_by_total]),

	:vnexpress_vaccine_to_vietnam
	=> clean_vaccine_to_vietnam(
		DATAFRAMES_RAW[:vnexpress][:vaccine_to_vietnam]),

	:vnexpress_vaccine_to_vietnam_expect
	=> clean_vaccine_to_vietnam_expect(
		DATAFRAMES_RAW[:vnexpress][:vaccine_to_vietnam]),
	
	:vnexpress_vaccine_vietnam_progress
	=> clean_vaccine_data_vietnam(
		DATAFRAMES_RAW[:vnexpress][:vaccine_data_vietnam]),
)

# ╔═╡ 9f7c09d8-fc02-4894-9cb3-c17ea157c71b
if (isnothing(overview_plot_date_begin) 
		|| isnothing(overview_plot_date_end)
		|| overview_plot_date_begin > overview_plot_date_end
		|| overview_plot_date_begin ∉ DATES
		|| overview_plot_date_end ∉ DATES)
	md"**Bad dates input**"
else
	let dates_to_plot = overview_plot_date_begin:Dates.Day(1):overview_plot_date_end;
		df = filter(x -> x.date in dates_to_plot,
			DATAFRAMES[:vnexpress_covid19_2021_by_day]);
		# Shared plot attributes
		xrotation = 45;
		yscale = overview_plot_log_y ? :log10 : :identity;
		layout = @layout([a{0.6h}; b c]);

		# Select dates to plot
		filter!(x -> x.date in dates_to_plot, df)

		# Avoid having 0 values in dataframe when plot with logarithmic scale
		if overview_plot_log_y
			df[!, [:cases_investigating, :cases_quarantined, :cases_imported]] .+= 1
		end

		let # Plot daily new cases
			subplot_daily = @df df myareaplot(
				:date,
				[:cases_investigating :cases_quarantined :cases_imported];
				label = ["new cases from unknown source" "new cases under quarantine" "new cases from immigrants"],
				yscale = yscale);

			subplot_mortality = @df df plot(
				:date, :mortality,
				label = "mortality rate (%)",
				color = PALETTE_COLORS[4],
				xrotation = xrotation)

			# Plot cummulative cases
			subplot_cummulative = @df df plot(
				:date, :cases_cummulative;
				label = "cummulative cases",
				linetype = :bar,
				color = PALETTE_COLORS[5],
				xrotation = xrotation,
				yscale = yscale)

			plot(subplot_daily, subplot_mortality, subplot_cummulative,
				plot_title = "Overview",
				layout = layout,
				size = (700, 700)
			)
		end
	end
end

# ╔═╡ bc1d8e14-0be1-4b87-a129-7b39251d60c5
if (isnothing(compositions_plot_date_begin) 
		|| isnothing(compositions_plot_date_end)
		|| compositions_plot_date_begin > compositions_plot_date_end
		|| compositions_plot_date_begin ∉ DATES
		|| compositions_plot_date_end ∉ DATES)
	md"**Bad dates input**"
else
	let dates_to_plot =
			compositions_plot_date_begin:Dates.Day(1):compositions_plot_date_end;
		df = filter(x -> x.date in dates_to_plot,
			DATAFRAMES[:vnexpress_covid19_2021_by_day]);
		xrotation = 45;
		layout = @layout([a; b c])

		let # Plot area chart for active cases, deaths and recovered
			subplot_composition_daily = @df df areaplot(
				:date,
				cols([:cases_investigating_weight,
						:cases_quarantined_weight,
						:cases_imported_weight]);
				label = label = ["new cases from unknown source (%)" "new cases under quarantine (%)" "new cases from immigrants (%)"],
				legend = :outertop);
			
			# Plot area chart for active cases, deaths and recovered
			subplot_composition_cumsum = @df df areaplot(
				:date,
				cols([:cases_cummulative_active_weight,
						:recovered_cummulative_weight,
						:deaths_cummulative_weight]);
				label = ["active cases" "recovered" "deaths"],
				palette = PALETTE_COLORS[2:end],
				legend = :outertop,
				xrotation = xrotation);

			# Plot percentage of cases that have to use ECMO and ICU
			subplot_lifesupport = @df df areaplot(:date,
				cols([:cases_cummulative_on_icu_percent,
						:cases_cummulative_on_ecmo_percent]),
				label = ["on ICU" "on ECMO"],
				palette = PALETTE_COLORS[8:end],
				xrotation = xrotation);

			plot(
				subplot_composition_daily,
				subplot_composition_cumsum,
				subplot_lifesupport,
				plot_title = "Compositions",
				layout = layout,
				size = (700, 700))
		end
	end
end

# ╔═╡ bb6d4ca5-3eb6-4405-90f5-add2d5f1c4ea
if (isnothing(status_plot_date_begin)
		|| isnothing(status_plot_date_end)
		|| status_plot_date_begin > status_plot_date_end
		|| status_plot_date_begin ∉ DATES
		|| status_plot_date_end ∉ DATES)
	md"**Bad dates input**"
else
	let # Select dates to plot
		dates_to_plot = status_plot_date_begin:Dates.Day(1):status_plot_date_end;
		df = filter(x -> x.date in dates_to_plot,
			DATAFRAMES[:vnexpress_covid19_2021_by_day]);
		# Shared plot attributes
		yscale = status_plot_log_y ? :log10 : :identity;
		plot_color_active = PALETTE_COLORS[2];
		plot_color_recovered = PALETTE_COLORS[3];
		plot_color_deaths = PALETTE_COLORS[4];
		xrotation = 45

		if status_plot_log_y
			df[!, [:deaths,
					:deaths_cummulative,
					:recovered,
					:recovered_cummulative,
					:cases_cummulative_active]] .+= 1
		end

		let	subplot_active_cumsum = @df df plot(
				:date, :cases_cummulative_active,
				label = "active cases",
				linetype = :bar,
				color = plot_color_active,
				xrotation = xrotation,
				yscale = yscale,
				);
			subplot_active_diff = @df df plot(
				:date, :cases_active,
				label = "active cases' diff.",
				color = plot_color_active,
				xrotation = xrotation);

			subplot_recovered_cumsum = @df df plot(
				:date, :recovered_cummulative,
				label = "total recovered",
				linetype = :bar,
				color = plot_color_recovered,
				xrotation = xrotation,
				yscale = yscale);
			subplot_recovered_daily = @df df plot(
				:date, :recovered,
				label = "daily recovered",				
				color = plot_color_recovered,
				xrotation = xrotation,
				yscale = yscale);

			subplot_deaths_cumsum = @df df plot(
				:date, :deaths_cummulative,
				label = "total deaths",
				xrotation = xrotation,
				linetype = :bar,
				color = plot_color_deaths,
				yscale = yscale);
			subplot_deaths_daily = @df df plot(
				:date, :deaths,
				label = "daily deaths",
				color = plot_color_deaths,
				xrotation = xrotation,
				yscale = yscale);

			plot(
				subplot_active_diff, subplot_active_cumsum,
				subplot_recovered_daily, subplot_recovered_cumsum,
				subplot_deaths_daily, subplot_deaths_cumsum,
				plot_title = "Cases' status",
				size = (700, 900),
				layout = @layout([a b; c d; e f])
			)
		end
	end
end

# ╔═╡ a606da0f-2f60-4b12-a56a-8ef9261c8cc6
if (isnothing(top8_locs_plot_date_begin)
		|| isnothing(top8_locs_plot_date_end)
		|| top8_locs_plot_date_begin > top8_locs_plot_date_end 
		|| top8_locs_plot_date_begin ∉ DATES
		|| top8_locs_plot_date_end ∉ DATES)
	md"**Bad dates input**"
else
	let # Select dates to plot
		dates_to_plot =
			top8_locs_plot_date_begin:Dates.Day(1):top8_locs_plot_date_end;
		df = filter(x -> x.date in dates_to_plot,
			DATAFRAMES[:vnexpress_covid19_2021_by_location]);
		# Sort and get the top 8 locations with highest daily cases
		top8 = sort(filter(
				cols -> cols.date == top8_locs_plot_date_end,
				stack(df, (2:size(df, 2)))
				), 
			order(:value, rev=true)
		)[1:8, :variable];
		yscale = top8_locs_plot_log_y ? :log10 : :identity

		if sum(last(df)[2:end]) != 0
			# Filter out locations that are not in the top 8
			select!(df, :date, top8)

			# Avoid having 0 values in dataframe when plot with logarithmic scale
			if top8_locs_plot_log_y
				df[!, top8] .+= 1
			end

			@df df plot(
				:date, cols([Symbol(loc) for loc in top8]),
				plot_title = "Daily new cases",
				label_title = "Top 8",
				xlabel = "Date",
				ylabel = "Cases count",
				legend = :outertopright,
				yscale = yscale,
			)
		else
			md"**Daily cases is not available for ranking**"
		end
	end
end

# ╔═╡ 908d8a8a-eaa5-4648-ae3d-d2bcba501379
if (isnothing(top8_locs_plot_date_begin)
		|| isnothing(top8_locs_plot_date_end)
		|| top8_locs_plot_date_begin > top8_locs_plot_date_end 
		|| top8_locs_plot_date_begin ∉ DATES
		|| top8_locs_plot_date_end ∉ DATES)
	md"**Bad dates input**"
else
	let # Select dates to plot
		dates_to_plot =
			top8_locs_plot_date_begin:Dates.Day(1):top8_locs_plot_date_end;
		df = filter(x -> x.date in dates_to_plot,
			DATAFRAMES[:vnexpress_covid19_2021_by_location_cumsum]);
		# Sort and get the top 8 locations with highest cummulative cases
		top8 = sort(filter(
				cols -> cols.date == top8_locs_plot_date_end,
				stack(df, (2:size(df, 2)))
				), 
			order(:value, rev=true)
		)[1:8, :variable];
		yscale = top8_locs_plot_log_y ? :log10 : :identity

		if sum(last(df)[2:end]) == 0
			md"**Cummulative cases is not available for ranking**"
		else
			# Filter out locations that are not in the top 8
			select!(df, :date, top8)

			# Avoid having 0 values in dataframe when plot with logarithmic scale
			if top8_locs_plot_log_y
				df[!, top8] .+= 1
			end

			@df df plot(
				:date, cols([Symbol(loc) for loc in top8]),
				title = "Cummulative cases",
				label_title = "Top 8",
				xlabel = "Date",
				ylabel = "Cases count",
				legend = :outertopright,
				yscale = yscale,
			)
		end
	end
end

# ╔═╡ eef505a5-0a58-4137-99e6-7effb2daf830
if isempty(locs_to_plot)
	md"**Location(s) not selected**"
elseif (isnothing(compare_locs_plot_date_begin)
		|| isnothing(compare_locs_plot_date_end)
		|| compare_locs_plot_date_begin > compare_locs_plot_date_end
		|| compare_locs_plot_date_begin ∉ DATES
		|| compare_locs_plot_date_end ∉ DATES)
	md"**Bad dates input**"
else
	let # Select dates to plot
		dates_to_plot =
			compare_locs_plot_date_begin:Dates.Day(1):compare_locs_plot_date_end;
		df = filter(x -> x.date in dates_to_plot,
			DATAFRAMES[:vnexpress_covid19_2021_by_location]);
		yscale = compare_locs_plot_log_y ? :log10 : :identity
		
		# Avoid -Inf with log
		if compare_locs_plot_log_y
			df[!, locs_to_plot] .+= 1
		end

		@df df plot(
			:date, cols(locs_to_plot);
			title = "Daily cases",
			xlabel = "Date",
			ylabel = "Cases count",
			yscale = yscale,
		)
	end
end

# ╔═╡ c7df24e3-37ff-45ea-950d-99f3c1c711ce
if isempty(locs_to_plot)
	md"**Location(s) not selected**"
elseif (isnothing(compare_locs_plot_date_begin)
		|| isnothing(compare_locs_plot_date_end)
		|| compare_locs_plot_date_begin > compare_locs_plot_date_end
		|| compare_locs_plot_date_begin ∉ DATES
		|| compare_locs_plot_date_end ∉ DATES)
	md"**Bad dates input**"
else
	let # Select dates to plot
		dates_to_plot =
			compare_locs_plot_date_begin:Dates.Day(1):compare_locs_plot_date_end;
		df = filter(x -> x.date in dates_to_plot,
			DATAFRAMES[:vnexpress_covid19_2021_by_location_cumsum]);
		yscale = compare_locs_plot_log_y ? :log10 : :identity
		
		# Avoid -Inf with log
		if compare_locs_plot_log_y
			df[!, locs_to_plot] .+= 1
		end

		@df df plot(
			:date, cols(locs_to_plot);
			title = "Cummulative cases",
			xlabel = "Date",
			ylabel = "Cases count",
			yscale = yscale,
		)
	end
end

# ╔═╡ f07fa737-fac0-4ea5-99b8-83650a2b0c3b
let df = copy(DATAFRAMES[:vnexpress_vaccine_vietnam_progress])

	total_pop_vn = sum(POPULATION_VN[!, :population])
	total_pop_vn_over18 = sum(POPULATION_VN[!, :population_over_18])
	
	subplot_vaccinated_percent = @df df areaplot(
		:date, 
		cols([:vaxed_partly_cumsum_weight, 
				:vaxed_fully_cumsum_weight]),
		title = "Overview",
		label=["partly vaccinated" "fully vaccinated"],
		ylims=(0, 1))
	
	hline!([total_pop_vn_over18 // total_pop_vn];
		label="population over 18",
		linewidth=2)
end

# ╔═╡ 0d05226a-08cd-4d9d-9e50-dbff53c98091
let df = copy(DATAFRAMES[:vnexpress_vaccine_vietnam_progress])

	subplot_vaccinated_daily = @df df areaplot(
		:date,
		cols([:vaxed_partly, :vaxed_fully]),
		title = "Daily vaccinations",
		label=["partly vaccinated" "fully vaccinated"])
end

# ╔═╡ c427e141-adc4-49ce-b060-9c99d6cdbb89
let df = copy(DATAFRAMES[:vnexpress_vaccine_to_vietnam])
	doses_expect = sum(DATAFRAMES[:vnexpress_vaccine_to_vietnam_expect][!, :doses])
	
	subplot_doses_received = @df df areaplot(
		:date,
		cols([Symbol(x) for x in VACCINE_TYPES .* "_cumsum"]),
		title = "Vaccine doses received",
		legend = :outertopright,
		label = permutedims(VACCINE_TYPES))
	
	hline!([doses_expect],
		label="expected to receive",
		linewidth=2)
end

# ╔═╡ e3b61ff5-9c86-42e4-a2f5-478bf2aa0c0c
let df = sort(
		DATAFRAMES[:vnexpress_vaccine_to_vietnam_expect],
		:doses, rev=true)
	
	names = CategoricalArray(df[!, :name])
	levels!(names, df[!, :name])

	subplot_pie = @df df pie(:name, :doses; legend=:none)
	subplot_bar = @df df bar(
		:name, :doses;
		legend = :none,
		groups = names,
		orientation = :h);
	
	plot(subplot_bar,
		subplot_pie,
		plot_title = "Vaccine doses expected",
		layout = @layout([a b]))
end

# ╔═╡ Cell order:
# ╟─52c5aa3b-31c9-41d6-b840-b766d8724932
# ╟─57eb35c4-c1e4-44d9-9d67-e085361bbfb4
# ╟─1ecf716e-a584-4013-852b-2f461f63fe66
# ╟─9f7c09d8-fc02-4894-9cb3-c17ea157c71b
# ╟─923f6fc4-02d0-41e0-92a8-27192c4c7137
# ╟─bc1d8e14-0be1-4b87-a129-7b39251d60c5
# ╟─8d1e5acb-996e-4edf-abd8-97eced94b3d0
# ╟─bb6d4ca5-3eb6-4405-90f5-add2d5f1c4ea
# ╟─fc216607-af60-431a-bac5-53240596b6a9
# ╟─1acb67e9-1a36-447d-a5a7-f5aba52d53d7
# ╟─a606da0f-2f60-4b12-a56a-8ef9261c8cc6
# ╟─908d8a8a-eaa5-4648-ae3d-d2bcba501379
# ╟─873db3d5-af35-4d03-b4ff-5a1f10ab4924
# ╟─fd11d312-8082-4faf-9551-dc597687f4ef
# ╟─f14c4beb-9803-40c3-8142-fd80e1cc96a2
# ╟─8ace2145-8521-45a9-83b1-ab8f6eadfaea
# ╟─eef505a5-0a58-4137-99e6-7effb2daf830
# ╟─c7df24e3-37ff-45ea-950d-99f3c1c711ce
# ╟─5dcca0d1-aabe-4512-a322-5e9fa3ebdb28
# ╟─f07fa737-fac0-4ea5-99b8-83650a2b0c3b
# ╟─0d05226a-08cd-4d9d-9e50-dbff53c98091
# ╟─c427e141-adc4-49ce-b060-9c99d6cdbb89
# ╟─e3b61ff5-9c86-42e4-a2f5-478bf2aa0c0c
# ╟─70584069-db75-4f6b-aa0d-43de20a36ed8
# ╟─87d376c4-074c-11ec-3a91-27b12d84faef
# ╟─4df3b761-c69a-4b96-81dc-08177d044447
# ╟─2f303728-e590-4b45-8e89-53b48f9ef242
# ╠═88e4d0b5-7024-45e4-b867-6da55f726d17
# ╠═06f0d4dc-25a2-4b3f-8558-d0b4935f7e99
# ╟─d9dabd88-5e88-4b94-816e-3545f598100b
# ╠═6f441a7a-97b8-4db3-84fa-34dc8971b8f8
# ╠═687209a9-a2ef-46af-99a7-571abf5e90c8
# ╟─bcc7b16f-9714-45e9-92bd-70dbea4b4cc6
# ╠═f8b80935-e3fc-4224-82a9-adf88c3bcc97
# ╟─ab548612-82a5-48fa-b81c-aae646666997
# ╠═48463954-2d4b-46fa-81ad-3e3c52420702
# ╟─85665111-9c21-457d-b4c2-d12521761522
# ╠═4b600132-f50e-4aaf-9646-a2bc4d643634
# ╠═7b9759f1-f696-4d50-822d-88df713fb575
# ╠═dede2946-ee8b-4a78-b9a6-e7e51eeeb41f
# ╠═0b642ad0-8648-41bd-8d75-062a50a0e0e3
# ╠═ed4ebadd-adb7-4c97-a044-48fcc37064b8
# ╠═1f807f44-8481-4ec1-86ae-e0cdbdfc03be
# ╠═c484ef80-eb8d-44be-929c-9e0085ce2f79
# ╠═23f785a7-e6d4-45d8-bc2e-584a915756cb
