#!/usr/bin/python3

import websocket
import threading
import _thread
import time
import rel


def on_message(ws, message):
    print("msg: ",message)

def on_error(ws, error):
    print("ERROR: ",error)

def on_close(ws, close_status_code, close_msg):
    print("### closed ###")

def on_open(ws):
    ws.send("Hello!")
    threading.Thread(target=go, args=("t1",ws,)).start()
    print("Opened connection")

def go(tag,ws):
    k = 0;
    while(k < 32):
        ws.send("(PING %s %s )" % (tag,k))
        k += 1
        time.sleep(0.5)
    ws.send("close")        

if __name__ == "__main__":
    #websocket.enableTrace(True)
    ws = websocket.WebSocketApp("ws://127.0.0.1:8034",
                              on_open=on_open,
                              on_message=on_message,
                              on_error=on_error,
                              on_close=on_close)
    

    ws.run_forever(dispatcher=rel, reconnect=5)  # Set dispatcher to automatic reconnection, 5 second reconnect delay if connection closed unexpectedly
    rel.signal(2, rel.abort)  # Keyboard Interrupt
    rel.dispatch()


