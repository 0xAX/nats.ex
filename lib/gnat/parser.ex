defmodule Gnat.Parser do
  require Logger
  # states: waiting, reading_message
  defstruct [
    partial: "",
    state: :waiting,
  ]

  def new, do: %Gnat.Parser{}

  def parse(parser, data) do
    parse(parser, data, [])
  end

  def parse(parser, "", parsed), do: {parser, Enum.reverse(parsed)}
  def parse(parser, "PING\r\n", _), do: {parser, [:ping]}
  def parse(parser, bytes, parsed) do
    {index, 2} = :binary.match(bytes, "\r\n")
    {command, "\r\n"<>rest} = String.split_at(bytes, index)
    {topic, sid, reply_to, bytesize} = parse_message_header(command)
    << message :: binary-size(bytesize), "\r\n", rest :: binary >> = rest
    parsed = [ {:msg, topic, sid, reply_to, message} | parsed]
    parse(parser, rest, parsed)
  end

  defp parse_message_header(str) do
    case String.split(str) do
      ["MSG", topic, sidstr, sizestr] -> {topic, String.to_integer(sidstr), nil, String.to_integer(sizestr)}
      ["MSG", topic, sidstr, reply_to, sizestr] -> {topic, String.to_integer(sidstr), reply_to, String.to_integer(sizestr)}
    end
  end
end
