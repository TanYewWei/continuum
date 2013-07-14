defmodule Date do
  @type year  :: non_neg_integer
  @type month :: 1 .. 12
  @type day   :: 1 .. 31
  @type week  :: 1 .. 53

  @type t :: { year, month, day } | { { year, month, day }, Timezone.t }

  @spec valid?(t) :: boolean
  def valid?({ year, month, day }) do
    :calendar.valid_date(year, month, day)
  end

  def valid?({ { year, month, day }, zone }) do
    Timezone.exists?(zone) and :calendar.valid_date(year, month, day)
  end

  @spec now             :: t
  @spec now(Timezone.t) :: t
  def now(zone // "UTC") do
    :calendar.now_to_datetime(:erlang.now) |> elem(0) |> timezone(zone)
  end

  @spec year(t) :: year
  def year({ date, _ }),    do: year(date)
  def year({ year, _, _ }), do: year

  @spec month(t) :: month
  def month({ date, _ }),     do: month(date)
  def month({ _, month, _ }), do: month

  @spec day(t) :: day
  def day({ date, _ }),   do: day(date)
  def day({ _, _, day }), do: day

  @spec timezone(t) :: Timezone.t
  def timezone({ _, _, _ }) do
    "UTC"
  end

  def timezone({ _, zone }) do
    zone
  end

  # TODO: actually do the date change
  @spec timezone(t, Timezone.t) :: t
  def timezone({ date, _old }, new) do
    if Timezone.equal? new, "UTC" do
      date
    else
      { new, date }
    end
  end

  def timezone(date, new) do
    if Timezone.equal? new, "UTC" do
      date
    else
      { date, new }
    end
  end

  @spec from_epoch(non_neg_integer) :: t
  def from_epoch(seconds) do
    (:calendar.datetime_to_gregorian_seconds(DateTime.epoch) + seconds)
      |> :calendar.gregorian_seconds_to_datetime
      |> elem(0)
  end

  @spec to_epoch(t) :: non_neg_integer
  def to_epoch(date) do
    zone = timezone(date)
    date = timezone(date, "UTC")

    if date < (DateTime.epoch |> DateTime.date) do
      raise ArgumentError, message: "cannot convert a date less than 1970-1-1"
    end

    :calendar.datetime_to_gregorian_seconds({ date, { 0, 0, 0 } }) -
      :calendar.datetime_to_gregorian_seconds(DataTime.epoch)
  end

  @doc """
  Using Date will import the `is_date` guards.
  """
  defmacro __using__(_opts) do
    quote do
      import Date, only: [is_date: 1, is_date: 2]
    end
  end

  @spec is_date(term) :: boolean
  defmacro is_date(var) do
    quote do
      ((tuple_size(unquote(var)) == 3 and elem(unquote(var), 0) > 0 and
                                          elem(unquote(var), 1) in 1 .. 12 and
                                          elem(unquote(var), 2) in 1 .. 32) or
       (tuple_size(unquote(var)) == 2 and is_binary(elem(unquote(var), 1)) and
         tuple_size(elem(unquote(var), 0)) == 3 and elem(elem(unquote(var), 0), 0) > 0 and
                                                    elem(elem(unquote(var), 0), 1) in 1 .. 12 and
                                                    elem(elem(unquote(var), 0), 2) in 1 .. 31))
    end
  end

  @spec is_date(term, Timezone.t) :: boolean
  defmacro is_date(var, zone) when is_binary(zone) do
    if Timezone.equal? zone, "UTC" do
      quote do
        (tuple_size(unquote(var)) == 3 and elem(unquote(var), 0) > 0 and
                                           elem(unquote(var), 1) in 1 .. 12 and
                                           elem(unquote(var), 2) in 1 .. 32)
      end
    else
      quote do
       (tuple_size(unquote(var)) == 2 and is_timezone(elem(unquote(var), 1), unquote(zone)) and
         tuple_size(elem(unquote(var), 0)) == 3 and elem(elem(unquote(var), 0), 0) > 0 and
                                                    elem(elem(unquote(var), 0), 1) in 1 .. 12 and
                                                    elem(elem(unquote(var), 0), 2) in 1 .. 31)
      end
    end
  end
end
