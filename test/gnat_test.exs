defmodule GnatTest do
  use ExUnit.Case
  doctest Gnat

  test "connect to a server" do
    {:ok, pid} = Gnat.start_link()
    assert Process.alive?(pid)
    :ok = Gnat.stop(pid)
  end

  test "subscribe to topic and receive a message" do
    {:ok, pid} = Gnat.start_link()
    {:ok, _ref} = Gnat.sub(pid, self(), "test")
    :ok = Gnat.pub(pid, "test", "yo dawg")

    assert_receive {:msg, "test", "yo dawg"}, 1000
    :ok = Gnat.stop(pid)
  end

  test "receive multiple messages" do
    {:ok, pid} = Gnat.start_link()
    {:ok, _ref} = Gnat.sub(pid, self(), "test")
    :ok = Gnat.pub(pid, "test", "message 1")
    :ok = Gnat.pub(pid, "test", "message 2")
    :ok = Gnat.pub(pid, "test", "message 3")

    assert_receive {:msg, "test", "message 1"}, 1000
    assert_receive {:msg, "test", "message 2"}, 1000
    assert_receive {:msg, "test", "message 3"}, 1000
    :ok = Gnat.stop(pid)
  end

  test "unsubscribing from a topic" do
    topic = "testunsub"
    {:ok, pid} = Gnat.start_link()
    {:ok, sub_ref} = Gnat.sub(pid, self(), topic)
    :ok = Gnat.pub(pid, topic, "msg1")
    assert_receive {:msg, ^topic, "msg1"}, 1000
    :ok = Gnat.unsub(pid, sub_ref)
    :ok = Gnat.pub(pid, topic, "msg2")
    receive do
      {:msg, _topic, _msg}=msg -> flunk("Received message after unsubscribe: #{inspect msg}")
      after 200 -> :ok
    end
  end

  test "unsubscribing from a topic after a maximum number of messages" do
    topic = "testunsub_maxmsg"
    {:ok, pid} = Gnat.start_link()
    {:ok, sub_ref} = Gnat.sub(pid, self(), topic)
    :ok = Gnat.unsub(pid, sub_ref, max_messages: 2)
    :ok = Gnat.pub(pid, topic, "msg1")
    :ok = Gnat.pub(pid, topic, "msg2")
    :ok = Gnat.pub(pid, topic, "msg3")
    assert_receive {:msg, ^topic, "msg1"}, 500
    assert_receive {:msg, ^topic, "msg2"}, 500
    receive do
      {:msg, _topic, _msg}=msg -> flunk("Received message after unsubscribe: #{inspect msg}")
      after 200 -> :ok
    end
  end
end
