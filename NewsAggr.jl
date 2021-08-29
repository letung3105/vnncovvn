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
			"Impute", "Plots", "StatsPlots"
			])
	
	using Dates, PlutoUI, DataFrames, Impute, Plots, StatsPlots
	import LinearAlgebra, HTTP, CSV
	
	gr()
	Plots.GRBackend()
	Plots.default(
		legend = :topleft,
		minorgrid = true,
		color_palette = :seaborn_deep,
	)
end;

# ╔═╡ 52c5aa3b-31c9-41d6-b840-b766d8724932
md"## Plots"

# ╔═╡ ec4728d1-2bc4-4da7-8290-565aaaf092b2
md"**$(@bind check_use_log_scale CheckBox()) Use logarithmic scale**"

# ╔═╡ ac8d0df6-013c-4598-8ee9-32d354849715
md"### Overview"

# ╔═╡ fc216607-af60-431a-bac5-53240596b6a9
md"### By location"

# ╔═╡ 873db3d5-af35-4d03-b4ff-5a1f10ab4924
md"#### Select locations to show on charts"

# ╔═╡ 70584069-db75-4f6b-aa0d-43de20a36ed8
md"## References"

# ╔═╡ 87d376c4-074c-11ec-3a91-27b12d84faef
SEEDS = Dict(
	:vnexpress => [
		"https://vnexpress.net/microservice/sheet/type/covid19_2021_by_total",
		"https://vnexpress.net/microservice/sheet/type/covid19_2021_by_location",
		"https://vnexpress.net/microservice/sheet/type/covid19_2021_by_day",
		"https://vnexpress.net/microservice/sheet/type/covid19_2021_by_map",
		"https://vnexpress.net/microservice/sheet/type/covid19_2021_281",
		# This one is JSON and it's not important parsing this
		# "https://vnexpress.net/microservice/sheet/type/vaccine_covid_19",
		"https://vnexpress.net/microservice/sheet/type/vaccine_data_vietnam",
		"https://vnexpress.net/microservice/sheet/type/vaccine_data_vietnam_city",
		"https://vnexpress.net/microservice/sheet/type/vaccine_to_vietnam",
		"https://vnexpress.net/microservice/sheet/type/vaccine_data_map",
	]
)

# ╔═╡ 4df3b761-c69a-4b96-81dc-08177d044447
md"## Glossary"

# ╔═╡ 85665111-9c21-457d-b4c2-d12521761522
md"### Helper functions"

# ╔═╡ 4b600132-f50e-4aaf-9646-a2bc4d643634
hasmissing(df::DataFrame) =
	any(Iterators.flatten(map(row -> ismissing.(values(row)), eachrow(df))))

# ╔═╡ 7b9759f1-f696-4d50-822d-88df713fb575
begin
	@userplot MyAreaPlot

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

# ╔═╡ 2f303728-e590-4b45-8e89-53b48f9ef242
md"### Data retrievals"

# ╔═╡ 88e4d0b5-7024-45e4-b867-6da55f726d17
begin
	DATAFRAMES = Dict(asyncmap(collect(keys(SEEDS))) do srcname
		srcname => Dict(asyncmap(SEEDS[srcname]) do url
			r = HTTP.get(url)
			df = CSV.read(r.body, DataFrame)
			dfname = last(split(url, c -> c == '/'))
			dfname => df
		end)
	end)
end;

# ╔═╡ 06f0d4dc-25a2-4b3f-8558-d0b4935f7e99
LOCATIONS = names(DATAFRAMES[:vnexpress]["covid19_2021_by_location"])[2:63]

# ╔═╡ fd11d312-8082-4faf-9551-dc597687f4ef
@bind locs_to_plot_binding MultiCheckBox(LOCATIONS)

# ╔═╡ b1cd1aa6-2dfe-4d02-983a-aa440d44550f
begin
	locs_to_plot = []
	if !isnothing(locs_to_plot_binding)
		append!(locs_to_plot, [Symbol(loc) for loc in locs_to_plot_binding])
	end
end;

# ╔═╡ d9dabd88-5e88-4b94-816e-3545f598100b
DATES = Date(2021, 4, 27):Dates.Day(1):Dates.today()

# ╔═╡ bcc7b16f-9714-45e9-92bd-70dbea4b4cc6
md"### Cleaned dataframes"

# ╔═╡ 5da0ef7d-ab07-403b-b9b3-7928202eebdb
md"#### Daily summaries"

# ╔═╡ dede2946-ee8b-4a78-b9a6-e7e51eeeb41f
begin
	df_covid19_summaries = copy(DATAFRAMES[:vnexpress]["covid19_2021_by_day"])
	
	# Convert string to date
	select!(
		df_covid19_summaries,
		"NGÀY" => (x -> begin
			dates = Date.(x, dateformat"dd/mm")
			Date.(2021, month.(dates), day.(dates))
			end) => "date",
		# All daily cases
		"new_cases" => "cases",
		# Daily active cases
		"new_active" => "cases_active",
		# Daily cases within the community
		"CỘNG ĐỒNG" => "cases_community",
		"blockade" => "cases_quarantined",
		"community" => "cases_investigating",
		# Daily cases from immigrants
		"imported" => "cases_imported",
		# All cummulative cases (since 27/04)
		"total_cases" => "cases_cummulative",
		# Cummulative active cases
		"total_active" => "cases_cummulative_active",
		# Cummulative cases within the community
		"TỔNG CỘNG ĐỒNG" => "cases_cummulative_community",
		# Cummulative cases with severe conditions 
		"ECMO" => "cases_cummulative_on_ecmo",
		"ICU_52" => "cases_cummulative_on_icu",
		# Daily deaths
		"new_deaths" => "deaths",
		# Cummulative deaths
		"total_deaths" => "deaths_cummulative",
		# Daily recovered
		"new_recovered" => "recovered",
		# Cummulative recovered
		"total_recovered_12" => "recovered_cummulative",
	)
	
	# Collect data starting from 27th April
	filter!(
		["date"] => cols -> cols .>= Date(2021, 4, 27) && cols .<= today(),
		df_covid19_summaries
	)
	
	df_covid19_summaries[!, "cases_investigating"] = 
	 	coalesce.(
			df_covid19_summaries[!, "cases_investigating"],
			df_covid19_summaries[!, "cases_community"],
		)
	df_covid19_summaries[!, "cases_quarantined"] = 
	 	coalesce.(df_covid19_summaries[!, "cases_quarantined"], 0)
	
	# Last Observered Carried Forward
	# Fill missing value with previously known value in the same column
	cols_cumulative_locf = [
		"cases_cummulative_on_ecmo",
		"cases_cummulative_on_icu",
		]
	df_covid19_summaries[1, cols_cumulative_locf[1]] = 0
	df_covid19_summaries[1, cols_cumulative_locf[2]] = 0
	df_covid19_summaries[!, cols_cumulative_locf] = 
		Impute.locf(df_covid19_summaries[!, cols_cumulative_locf])
	
	@assert !hasmissing(df_covid19_summaries)
	df_covid19_summaries
end

# ╔═╡ 9f7c09d8-fc02-4894-9cb3-c17ea157c71b
begin
	let # Normalized active cases, deaths, and recovered
		df_my_summary = transform(df_covid19_summaries,
			
			:cases_investigating => (x -> x .+ 1) => :cases_investigating,
			:cases_quarantined => (x -> x .+ 1) => :cases_quarantined,
			:cases_imported => (x -> x .+ 1) => :cases_imported,
			
			[:cases_cummulative, :deaths_cummulative, :recovered_cummulative]
				=> ((x, y, z) -> (1 .- y./x .- z./x))
				=> :cases_cummulative_active_weight,
			
			[:cases_cummulative, :deaths_cummulative]
				=> ((x, y) -> y ./ x)
				=> :deaths_cummulative_weight,
			
			[:cases_cummulative, :recovered_cummulative]
				=> ((x, y) -> y ./ x)
				=> :recovered_cummulative_weight,
		)
		
		let # Plot daily new cases
			subplot1 = @df df_my_summary myareaplot(
				:date,
				[:cases_investigating :cases_quarantined :cases_imported];
				label = ["under investigation" "in quarantine" "from immigrants"],
				plot_title="daily new cases",
				yscale = check_use_log_scale ? :log10 : :identity,
			);
			
			# Plot area chart for active cases, deaths and recovered
			subplot2 = @df df_my_summary areaplot(
				:date,
				[:cases_cummulative_active_weight :recovered_cummulative_weight :deaths_cummulative_weight];
				label = ["active cases (%)" "recovered (%)" "deaths (%)"],
				legend = :outertop,
				rotation = 45,
			);
			
			# Plot cummulative cases
			subplot3 = @df df_my_summary bar(
				:date, :cases_cummulative;
				label = "cummulative cases",
				rotation = 45,
				yscale = check_use_log_scale ? :log10 : :identity,
			)
		
			plot(subplot1, subplot2, subplot3,
				layout = @layout([a; b c]), size = (700, 700))
		end
	end
end

# ╔═╡ 56127caa-7ec9-45ba-ae3a-aaf8fbd78dc1
begin
	let # Get mortality rates with deaths / cases
		df_mortality = select(
			df_covid19_summaries,
			"date",
			["deaths_cummulative", "cases_cummulative"] => (
				(deaths, cases) -> deaths./cases.*100
				) => "mortality"
		)
		
		# Plot mortality rate
		@df df_mortality plot(
			:date, :mortality,
			color = :red,
			legend = :none,
			title = "Overall mortality rates (since 27th April, 2021)",
			xlabel = "Date",
			ylabel = "Mortality rate (%)",
		)
	end
end

# ╔═╡ f7549e5f-60f1-4530-bec4-88b020f65a46
md"#### Cummulative cases since 27th April"

# ╔═╡ 0b642ad0-8648-41bd-8d75-062a50a0e0e3
begin
	df_covid19_by_location_cummulative = 
		copy(DATAFRAMES[:vnexpress]["covid19_2021_by_total"])
	
	# Remove the first row that has missing date
	delete!(df_covid19_by_location_cummulative, 1)
	
	# Convert string to date
	select!(
		df_covid19_by_location_cummulative,
		"Ngày" => x -> begin
			dates = Date.(x, dateformat"dd/mm")
			Date.(2021, month.(dates), day.(dates))
		end,
		LOCATIONS;
		renamecols = false
	)
	
	# Collect data starting from 27th April
	filter!(
		["Ngày"] => cols -> cols .>= Date(2021, 4, 27) && cols .<= today(),
		df_covid19_by_location_cummulative
	)

	# Show be no missing field
	@assert !hasmissing(df_covid19_by_location_cummulative)
	df_covid19_by_location_cummulative
end

# ╔═╡ 908d8a8a-eaa5-4648-ae3d-d2bcba501379
begin
	let sorted_locs =
			sort(filter(
					cols -> cols["Ngày"] == Dates.today(),
					stack(df_covid19_by_location_cummulative, (2:63))),
				order(:value, rev=true));
		
		df_loc_cummulative = select(
			df_covid19_by_location_cummulative,
			"Ngày", 
			sorted_locs[1:8, :variable]
		);
		
		top8 = [Symbol(loc) for loc in sorted_locs[1:8, :variable]]
		
		df_loc_cummulative[!, top8] .+= 1
		
		@df df_loc_cummulative plot(
			:Ngày, cols(top8),
			plot_title = "Commulative cases (since 27th April, 2021)",
			label_title = "Top 8",
			xlabel = "Date",
			ylabel = "Cases count",
			yscale = check_use_log_scale ? :log10 : :identity,
		)
	end
end

# ╔═╡ c7df24e3-37ff-45ea-950d-99f3c1c711ce
begin
	if !isempty(locs_to_plot)
		let df_loc_cummulative = copy(df_covid19_by_location_cummulative)
			
			df_loc_cummulative[!, locs_to_plot] =
				df_loc_cummulative[!, locs_to_plot] .+ 1

			@df df_loc_cummulative plot(
				:Ngày, cols(locs_to_plot);
				plot_title = "Cummulative cases (since 27th April, 2021)",
				xlabel = "Date",
				ylabel = "Cases count",
				yscale = check_use_log_scale ? :log10 : :identity,
			)
		end
	end
end

# ╔═╡ 8e812230-5284-4a9a-b16a-c054a12407f5
md"#### Daily cases since 27th April"

# ╔═╡ ed4ebadd-adb7-4c97-a044-48fcc37064b8
begin
	df_covid19_by_location_daily =
		copy(DATAFRAMES[:vnexpress]["covid19_2021_by_location"])

	# Remove the first row that has missing date
	delete!(df_covid19_by_location_daily, 1)
	
	# Convert string to date
	select!(
		df_covid19_by_location_daily,
		"Ngày" => x -> begin
			dates = Date.(x, dateformat"dd/mm")
			Date.(2021, month.(dates), day.(dates))
		end,
		LOCATIONS;
		renamecols = false
	)
	
	# Collect data starting from 27th April
	filter!(
		["Ngày"] => cols -> cols .>= Date(2021, 4, 27) && cols .<= today(),
		df_covid19_by_location_daily
	)
	
	# Replace missing with 0
	df_covid19_by_location_daily = coalesce.(df_covid19_by_location_daily, 0)
	
	# Show be no missing field
	@assert !hasmissing(df_covid19_by_location_daily)
	df_covid19_by_location_daily
end

# ╔═╡ a606da0f-2f60-4b12-a56a-8ef9261c8cc6
begin
	let sorted_locs =
			sort(filter(
					cols -> cols["Ngày"] == Dates.today(),
					stack(df_covid19_by_location_daily, (2:63))),
				order(:value, rev=true));
		
		df_loc_daily = select(
			df_covid19_by_location_daily,
			"Ngày", 
			sorted_locs[1:8, :variable]
		);
		
		top8 = [Symbol(loc) for loc in sorted_locs[1:8, :variable]]
		
		df_loc_daily[!, top8] .+= 1
		
		@df df_loc_daily plot(
			:Ngày, cols(top8),
			plot_title = "Daily new cases (since 27th April, 2021)",
			label_title = "Top 8",
			xlabel = "Date",
			ylabel = "Cases count",
			yscale = check_use_log_scale ? :log10 : :identity,
		)
	end
end

# ╔═╡ eef505a5-0a58-4137-99e6-7effb2daf830
begin
	if !isempty(locs_to_plot)
		let df_loc_daily = copy(df_covid19_by_location_daily)
			df_loc_daily[!, locs_to_plot] =
				df_loc_daily[!, locs_to_plot] .+ 1

			@df df_loc_daily plot(
				:Ngày, cols(locs_to_plot),
				plot_title = "Daily cases (since 27th April, 2021)",
				xlabel = "Date",
				ylabel = "Cases count",
				yscale = check_use_log_scale ? :log10 : :identity,
			)
		end
	end
end

# ╔═╡ ab548612-82a5-48fa-b81c-aae646666997
md"### Packages"

# ╔═╡ Cell order:
# ╟─52c5aa3b-31c9-41d6-b840-b766d8724932
# ╟─ec4728d1-2bc4-4da7-8290-565aaaf092b2
# ╟─ac8d0df6-013c-4598-8ee9-32d354849715
# ╟─9f7c09d8-fc02-4894-9cb3-c17ea157c71b
# ╟─56127caa-7ec9-45ba-ae3a-aaf8fbd78dc1
# ╟─fc216607-af60-431a-bac5-53240596b6a9
# ╟─a606da0f-2f60-4b12-a56a-8ef9261c8cc6
# ╟─908d8a8a-eaa5-4648-ae3d-d2bcba501379
# ╟─873db3d5-af35-4d03-b4ff-5a1f10ab4924
# ╟─fd11d312-8082-4faf-9551-dc597687f4ef
# ╟─b1cd1aa6-2dfe-4d02-983a-aa440d44550f
# ╟─c7df24e3-37ff-45ea-950d-99f3c1c711ce
# ╟─eef505a5-0a58-4137-99e6-7effb2daf830
# ╟─70584069-db75-4f6b-aa0d-43de20a36ed8
# ╟─87d376c4-074c-11ec-3a91-27b12d84faef
# ╟─4df3b761-c69a-4b96-81dc-08177d044447
# ╟─85665111-9c21-457d-b4c2-d12521761522
# ╠═4b600132-f50e-4aaf-9646-a2bc4d643634
# ╠═7b9759f1-f696-4d50-822d-88df713fb575
# ╟─2f303728-e590-4b45-8e89-53b48f9ef242
# ╠═88e4d0b5-7024-45e4-b867-6da55f726d17
# ╟─06f0d4dc-25a2-4b3f-8558-d0b4935f7e99
# ╟─d9dabd88-5e88-4b94-816e-3545f598100b
# ╟─bcc7b16f-9714-45e9-92bd-70dbea4b4cc6
# ╟─5da0ef7d-ab07-403b-b9b3-7928202eebdb
# ╟─dede2946-ee8b-4a78-b9a6-e7e51eeeb41f
# ╟─f7549e5f-60f1-4530-bec4-88b020f65a46
# ╟─0b642ad0-8648-41bd-8d75-062a50a0e0e3
# ╟─8e812230-5284-4a9a-b16a-c054a12407f5
# ╟─ed4ebadd-adb7-4c97-a044-48fcc37064b8
# ╟─ab548612-82a5-48fa-b81c-aae646666997
# ╠═48463954-2d4b-46fa-81ad-3e3c52420702
