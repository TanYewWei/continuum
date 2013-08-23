defmodule DateTime do
  use Date
  use Time

  @type t :: { Date.t, Time.t } | { Timezone.t, { Date.t, Time.t } }

  @doc """
  Herp derp.
  """
  defmacro __using__(_opts) do
    quote do
      use Date
      use Time

      import DateTime, only: [is_datetime: 1, is_datetime: 2, sigil_t: 2, sigil_T: 2]
    end
  end

  @spec is_datetime(term) :: boolean
  defmacro is_datetime(var) do
    quote do
      (tuple_size(unquote(var)) == 2 and
        (is_date(elem(unquote(var), 0)) and is_time(elem(unquote(var), 1))) or
        (is_binary(elem(unquote(var), 1)) and
          is_date(elem(elem(unquote(var), 0), 0)) and
          is_time(elem(elem(unquote(var), 0), 1))))
    end
  end

  @spec is_datetime(term, Timezone.t) :: boolean
  defmacro is_datetime(var, zone) when is_binary(zone) do
    if Timezone.equal? zone, "UTC" do
      quote do
        (tuple_size(unquote(var)) == 2 and
          (is_date(elem(unquote(var), 0), unquote(zone)) and
          is_time(elem(unquote(var), 1), unquote(zone))))
      end
    else
      quote do
        (is_timezone(elem(unquote(var), 1), unquote(zone)) and
          is_date(elem(elem(unquote(var), 0), 0)) and
          is_time(elem(elem(unquote(var), 0), 1)))
      end
    end
  end

  @spec sigil_t(String.t, [?d | ?t | ?f]) :: t
  defmacro sigil_t({ _, _, [string] }, 'f') when is_binary(string) do
    Macro.escape parse_format(string)
  end

  defmacro sigil_t(string, 'f') do
    quote do
      DateTime.parse_format(unquote(string))
    end
  end

  defmacro sigil_t({ _, _, [string] }, options) when is_binary(string) do
    Macro.escape parse_datetime(string, options)
  end

  defmacro sigil_t(string, options) do
    quote do
      DateTime.parse_datetime(unquote(string), unquote(options))
    end
  end

  @spec sigil_T(String.t, [?d | ?t | ?f]) :: t
  defmacro sigil_T({ _, _, [string] }, 'f') when is_binary(string) do
    Macro.escape parse_format(string)
  end

  defmacro sigil_T({ _, _, [string] }, options) when is_binary(string) do
    Macro.escape parse_datetime(string, options)
  end

  @doc false
  def parse_datetime(string, options) do
    if string |> is_binary do
      string = String.to_char_list!(string)
    end

    { :ok, lexed, _  } = :datetime_lexer.string(string)
    { :ok, parsed }    = :datetime_parser.parse(lexed)

    cond do
      Enum.empty?(options) or (Enum.member?(options, ?d) and Enum.member?(options, ?t)) ->
        parsed

      Enum.member?(options, ?d) ->
        if DateTime.valid?(parsed) do
          DateTime.date(parsed)
        else
          parsed
        end

      Enum.member?(options, ?t) ->
        if DateTime.valid?(parsed) do
          DateTime.time(parsed)
        else
          parsed
        end

      true ->
        raise ArgumentError, message: "#{inspect options} is not supported"
    end
  end

  @doc false
  def parse_format(string, type // :php) do
    if string |> is_binary do
      string = String.to_char_list!(string)
    end

    { :ok, lexed, _ } = case type do
      :php ->
        :dt_format_php.string(string)
    end

    { :ok, parsed } = :dt_format.parse(lexed)

    parsed
  end

  @spec valid?(t) :: boolean
  def valid?({ { _, _ }, { _, _, _ } }) do
    false
  end

  def valid?({ { _, _, _ }, { _, _ } }) do
    false
  end

  def valid?({ { date, time }, zone }) do
    Timezone.exists?(zone) and Date.valid?(date) and Time.valid?(time)
  end

  def valid?({ date, time }) do
    Date.valid?(date) and Time.valid?(time)
  end

  @spec new(Date.t) :: t
  def new({ date, zone }) do
    { { date, { 0, 0, 0 } }, zone }
  end

  def new({ _, _, _ } = date) do
    { date, { 0, 0, 0 } }
  end

  @spec new(Date.t, Time.t) :: t
  def new({ _, _, _ } = date, { _, _, _ } = time) do
    { date, time }
  end

  def new({ date, zone_a }, { time, zone_b }) do
    unless Timezone.equal?(zone_a, zone_b) do
      raise ArgumentError, message: "timezone mismatch between date and time"
    end

    { { date, time }, zone_a }
  end

  def new({ date, zone }, { _, _, _ } = time) do
    { { date, time }, zone }
  end

  def new({ _, _, _ } = date, { time, zone }) do
    { { date, time }, zone }
  end

  @spec now             :: t
  @spec now(Timezone.t) :: t
  def now(zone // "UTC") do
    :calendar.now_to_datetime(:erlang.now) |> timezone(zone)
  end

  @spec date(t) :: Date.t
  def date({ { date, _ }, zone }) do
    { date, zone }
  end

  def date({ date, _ }) do
    date
  end

  @spec date(t, Date.t) :: t
  def date({ { _old, time }, zone }, new) do
    { { new, time }, zone }
  end

  def date({ _old, time }, new) when is_date(new, "UTC") do
    { new, time }
  end

  def time({ { _, time }, zone }) do
    { time, zone }
  end

  def time({ _, time }) do
    time
  end

  @spec timezone(t) :: Timezone.t
  def timezone({ { _, _ }, zone }) do
    zone
  end

  def timezone(_) do
    "UTC"
  end

  # TODO: actually change the date and time
  @spec timezone(t, Timezone.t) :: t
  def timezone({ { _, _ } = datetime, _old }, new) do
    if Timezone.equal? new, "UTC" do
      datetime
    else
      { datetime, new }
    end
  end

  def timezone(datetime, new) do
    if Timezone.equal? new, "UTC" do
      datetime
    else
      { datetime, new }
    end
  end

  @spec dst?(t) :: boolean
  def dst?(datetime) do
    zone = timezone(datetime)

    false
  end

  @spec format(t, String.t | list | tuple) :: String.t
  def format(datetime, format) when is_binary(format) do
    datetime |> format(parse_format(format))
  end

  def format(datetime, format) when is_list(format) do
    format([], datetime, format)
  end

  def format(datetime, { :day, :number, :padded }) do
    datetime |> date |> Date.day |> pad
  end

  def format(datetime, { :weekday, :name, :short }) do
    case datetime |> date |> Date.day_of_the_week do
      1 -> "Mon"
      2 -> "Tue"
      3 -> "Wed"
      4 -> "Thu"
      5 -> "Fri"
      6 -> "Sat"
      7 -> "Sun"
    end
  end

  def format(datetime, { :day, :number }) do
    datetime |> date |> Date.day |> integer_to_binary
  end

  def format(datetime, { :weekday, :name, :long }) do
    case datetime |> date |> Date.day_of_the_week do
      1 -> "Monday"
      2 -> "Tuesday"
      3 -> "Wednesday"
      4 -> "Thursday"
      5 -> "Friday"
      6 -> "Saturday"
      7 -> "Sunday"
    end
  end

  def format(datetime, { :weekday, :number, :iso8601 }) do
    datetime |> date |> Date.day_of_the_week |> integer_to_binary
  end

  def format(datetime, :suffix) do
    case datetime |> date |> Date.day |> rem(10) do
      1 -> "st"
      2 -> "nd"
      3 -> "rd"
      _ -> "th"
    end
  end

  def format(datetime, { :weekday, :number }) do
    case datetime |> date |> Date.day_of_the_week do
      7 -> "0"
      n -> integer_to_binary(n)
    end
  end

  def format(datetime, :yearday) do
    datetime |> date > Date.day_of_the_year |> integer_to_binary
  end

  def format(datetime, { :week, :number, :iso8601 }) do
    datetime |> date |> Date.week_number |> integer_to_binary
  end

  def format(datetime, { :month, :name, :long }) do
    case datetime |> date |> Date.month do
      1  -> "January"
      2  -> "February"
      3  -> "March"
      4  -> "April"
      5  -> "May"
      6  -> "June"
      7  -> "July"
      8  -> "August"
      9  -> "September"
      10 -> "October"
      11 -> "November"
      12 -> "December"
    end
  end

  def format(datetime, { :month, :number, :padded }) do
    datetime |> date |> Date.month |> pad
  end

  def format(datetime, { :month, :name, :short }) do
    case datetime |> date |> Date.month do
      1  -> "Jan"
      2  -> "Feb"
      3  -> "Mar"
      4  -> "Apr"
      5  -> "May"
      6  -> "Jun"
      7  -> "Jul"
      8  -> "Aug"
      9  -> "Sep"
      10 -> "Oct"
      11 -> "Nov"
      12 -> "Dec"
    end
  end

  def format(datetime, { :month, :number }) do
    datetime |> date |> Date.month |> integer_to_binary
  end

  def format(datetime, { :month, :days }) do
    datetime |> date |> Date.month_days |> integer_to_binary
  end

  def format(datetime, { :year, :leap }) do
    case datetime |> date |> Date.leap? do
      true  -> "1"
      false -> "0"
    end
  end

  def format(datetime, { :year, :number, :iso8601 }) do
    datetime |> date |> Date.year |> integer_to_binary
  end

  def format(datetime, { :year, :number, :long }) do
    datetime |> date |> Date.year |> integer_to_binary
  end

  def format(datetime, { :year, :number, :short }) do
    datetime |> date |> Date.year |> rem(100) |> integer_to_binary
  end

  def format(datetime, { :noon, :lowercase }) do
    case datetime |> time |> Time.hour do
      hour when hour > 12  -> "pm"
      hour when hour <= 12 -> "am"
    end
  end

  def format(datetime, { :noon, :uppercase }) do
    case datetime |> time |> Time.hour do
      hour when hour > 12  -> "PM"
      hour when hour <= 12 -> "AM"
    end
  end

  def format(datetime, { :hour, 12 }) do
    datetime |> time |> Time.hour |> rem(12) |> integer_to_binary
  end

  def format(datetime, { :hour, 24 }) do
    datetime |> time |> Time.hour |> integer_to_binary
  end

  def format(datetime, { :hour, 12, :padded }) do
    datetime |> time |> Time.hour |> rem(12) |> pad
  end

  def format(datetime, { :hour, 24, :padded }) do
    datetime |> time |> Time.hour |> pad
  end

  def format(datetime, { :minute, :padded }) do
    datetime |> time |> Time.minute |> pad
  end

  def format(datetime, { :second, :padded }) do
    datetime |> time |> Time.second |> pad
  end

  def format(datetime, { :timezone, :long }) do
    datetime |> timezone
  end

  def format(datetime, :daylight) do
    case datetime |> dst? do
      true  -> "1"
      false -> "0"
    end
  end

  def format(datetime, { :offset, :short }) do
    case Timezone.offset("UTC", datetime) do
      { sign, { hours, minutes, _ } } ->
        atom_to_binary(sign) <> (hours |> pad) <> (minutes |> pad)
    end
  end

  def format(datetime, { :offset, :long }) do
    case Timezone.offset("UTC", datetime) do
      { sign, { hours, minutes, _ } } ->
        atom_to_binary(sign) <> (hours |> pad) <> ":" <>  (minutes |> pad)
    end
  end

  def format(datetime, { :timezone, :short }) do
    datetime |> timezone
  end

  def format(datetime, { :offset, :seconds }) do
    case Timezone.offset("UTC", datetime) do
      { sign, time } ->
        atom_to_binary(sign) <> (Time.to_seconds(time) |> integer_to_binary)
    end
  end

  def format(datetime, { :datetime, :iso8601 }) do
    datetime |> format(%t"o-m-d\TH:i:sP"f)
  end

  def format(datetime, { :datetime, :rfc2882 }) do
    datetime |> format(%t"D, j M Y H:i:s O"f)
  end

  def format(datetime, :epoch) do
    datetime |> to_epoch |> integer_to_binary
  end

  def format(_, char) when is_integer(char) do
    [char] |> list_to_binary
  end

  defp format(acc, datetime, [format | rest]) do
    [format(datetime, format) | acc] |> format(datetime, rest)
  end

  defp format(acc, _, []) do
    Enum.reverse(acc) |> iolist_to_binary
  end

  defp pad(number) when number < 10 do
    "0" <> integer_to_binary(number)
  end

  defp pad(number) do
    integer_to_binary(number)
  end

  @spec epoch :: t
  def epoch do
    { { 1970, 1, 1 }, { 0, 0, 0 } }
  end

  @spec to_epoch(t) :: non_neg_integer
  def to_epoch(datetime) do
    zone     = timezone(datetime)
    datetime = timezone(datetime, "UTC")

    if datetime < epoch do
      raise ArgumentError, message: "cannot convert a datetime less than 1970-1-1 00:00:00"
    end

    :calendar.datetime_to_gregorian_seconds(datetime) -
      :calendar.datetime_to_gregorian_seconds(epoch)
  end

  @spec from_epoch(non_neg_integer) :: t
  def from_epoch(seconds) do
    (:calendar.datetime_to_gregorian_seconds(DateTime.epoch) + seconds)
      |> :calendar.gregorian_seconds_to_datetime
  end
end
