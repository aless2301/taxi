defmodule TaxiBeWeb.TaxiAllocationJob do
  use GenServer

  def start_link(request, name) do
    GenServer.start_link(__MODULE__, request, name: name)
  end

  def init(request) do
    Process.send(self(), :part1, [:nosuspend])
    {:ok, %{request: request, timer: nil, accepted: false}}
  end

  def handle_info(:part1,  %{request: request} = state) do
    Process.sleep(1000)

    task = Task.async( fn -> candidate_taxis() end)

    customer_username = state.request["username"]

    # Computation of fare
    #TaxiBeWeb.Endpoint.broadcast("customer:"<>customer_username, "booking_request", %{msg: "Your ride is worth 80 pesitos"})
    # línea 20 — reemplazar el broadcast hardcodeado por:
    request |> compute_ride_fare() |> notify_customer_ride_fare()
    taxis = Task.await(task)

    candidates = Enum.take(Enum.shuffle(taxis),3)
    new_state = state |> Map.put(:taxis, candidates) |> Map.put(:accepted, false)
    timer = part2(new_state)

    #{taxi, others, timer} = part2(state |> Map.put(:taxis, taxis |> Enum.shuffle))
    {:noreply, new_state |> Map.put(:timer, timer)}
  end

  def handle_info(:timeout, state) do
    customer_username = state.request["username"]
    TaxiBeWeb.Endpoint.broadcast(
      "customer:" <> customer_username,
      "booking_request",
      %{msg: "We are sorry, no driver is available right now. Please try again later."}
    )
    {:stop, :normal, state}
  end


  def part2(state) do
    %{taxis: taxis, request: request} = state

    # Forward request to taxi driver
    %{
      "pickup_address" => pickup_address,
      "dropoff_address" => dropoff_address,
      "booking_id" => booking_id
    } = request

    Enum.each(taxis, fn taxi ->
      TaxiBeWeb.Endpoint.broadcast(
        "driver:" <> taxi.nickname,
        "booking_request",
        %{
          msg: "Viaje de '#{pickup_address}' a '#{dropoff_address}'",
          bookingId: booking_id
          })
    end )
    Process.send_after(self(), :timeout, 10000) #change after tests to 9000

  end


  def handle_cast({:process_reject, _driver_username}, state) do
    {:noreply, state}
  end

  def handle_cast({:process_accept, _driver_username}, state) do
    #IO.inspect(request)
    #IO.inspect(state)}
    customer_username = state.request["username"]

    if state.accepted do
      {:noreply, state}
    else

      %{timer: timer} = state

      if timer != nil do
        Process.cancel_timer(timer)
      end

      TaxiBeWeb.Endpoint.broadcast("customer:"<>customer_username, "booking_request", %{msg: "Tu taxi llegará en  5 min"})
      {:noreply, state |> Map.put(:accepted, true)}
    end
  end

  def compute_ride_fare(request) do
    %{
      "pickup_address" => pickup_address,
      "dropoff_address" => dropoff_address
    } = request

    # coord1 = TaxiBeWeb.Geolocator.geocode(pickup_address)
    # coord2 = TaxiBeWeb.Geolocator.geocode(dropoff_address)
    # {distance, _duration} = TaxiBeWeb.Geolocator.distance_and_duration(coord1, coord2)
    {request, 80.0} # Float.ceil(distance/300)}
  end

  def notify_customer_ride_fare({request, fare}) do
    %{"username" => customer} = request
  TaxiBeWeb.Endpoint.broadcast("customer:" <> customer, "booking_request", %{msg: "Ride fare: #{fare}"})
  end

  def select_candidate_taxis(%{"pickup_address" => _pickup_address}) do
    [
      %{nickname: "angelopolis", latitude: 19.0319783, longitude: -98.2349368},
      %{nickname: "arcangeles", latitude: 19.0061167, longitude: -98.2697737},
      %{nickname: "destino", latitude: 19.0092933, longitude: -98.2473716}
    ]
  end

  def candidate_taxis() do
    [
      %{nickname: "frodo", latitude: 19.0319783, longitude: -98.2349368}, # Angelopolis
      %{nickname: "samwise", latitude: 19.0061167, longitude: -98.2697737}, # Arcangeles
      %{nickname: "pippin", latitude: 19.0092933, longitude: -98.2473716} # Paseo Destino
    ]
  end
end
