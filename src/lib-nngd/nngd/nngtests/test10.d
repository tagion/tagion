module nngd.nngtests.test10;

import std.stdio;
import std.concurrency;
import std.exception;
import std.json;
import std.format;
import std.conv;
import std.path;
import std.file;
import std.uuid;
import std.regex;
import std.json;
import std.exception;
import core.thread;
import core.thread.osthread;

import nngd;
import nngd.nngtests.suite;
import nngd.nngtests.testdata;

const _testclass = "nngd.nngtests.nng_test10_tls";

@trusted class nng_test10_tls : NNGTest {
    
    this(Args...)(auto ref Args args) { super(args); }    

    override string[] run(){
        log("NNG test 10: TLS");
        version(withtls)
        {
            this.uri = "tls+tcp://127.0.0.1:31010";
            workers ~= new Thread(&(this.receiver_worker)).start();
            workers ~= new Thread(&(this.sender_worker)).start();
            foreach(w; workers)
                w.join();
        } version(withtls)
        log(_testclass ~ ": Bye!");
        return [];
    }
    
    version(withtls)
    {
        void sender_worker() @trusted {
            const NDIALS = 32;
            const NMSGS = 32;
            uint k = 0;
            int rc;
            try{
                thread_attachThis();
                rt_moduleTlsCtor();
                log("SS: Conncting to " ~ uri);
                NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_PUSH);
                s.sendtimeout = msecs(1000);
                s.sendbuf = 4096;

                rc = s.dialer_create(uri);
                enforce(rc == 0, "Dialer create: " ~ nng_errstr(rc));        
                
                NNGTLS tls = NNGTLS(nng_tls_mode.NNG_TLS_MODE_CLIENT);
                tls.set_ca_chain(NNGTEST_SSL_CERT);
                tls.set_server_name("localhost");
                tls.set_auth_mode(nng_tls_auth_mode.NNG_TLS_AUTH_MODE_NONE);

                log(tls.toString());

                rc = s.dialer_set_tls(&tls);
                enforce(rc == 0, "Dialer set TLS: " ~ nng_errstr(rc));        

                while( ++k < NDIALS ){
                    rc = s.dialer_start();
                    if(rc == 0) break;
                    if(rc == nng_errno.NNG_ECONNREFUSED){
                        log("SS: Connection refused attempt %d", k);
                        nng_sleep(msecs(100));
                        continue;
                    }
                    error("SS: Dial error after %d attempts: %d", NDIALS, rc);
                    enforce(rc == 0);
                }
                if(s.state is nng_socket_state.NNG_STATE_CONNECTED){
                    log("SS:  connected with : " ~ nng_errstr(s.errno));
                }else{
                    enforce(false, "SS: connection timed out");
                }
                k = 0;
                while(++k < NMSGS){
                    auto line = format(`{"msg": %d, "check": %d, "time": %f}`,
                        k, mkrot3(k), timestamp());
                    if(k == NMSGS-1) line = "END";    
                    log(line);   
                    rc = s.send!string(line);
                    enforce(rc == 0);
                    log("SS: sent: " ~ line);
                    nng_sleep(msecs(100));
                }
                nng_sleep(msecs(100));
            } catch(Throwable e) {
                error(dump_exception_recursive(e, "SS: Sender worker"));
            }
        }

        void receiver_worker() @trusted {
            const NDIALS = 32;
            uint k = 0;
            int rc;
            bool _ok = false;
            try{
                thread_attachThis();
                rt_moduleTlsCtor();
                NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_PULL);
                s.recvtimeout = msecs(1000);
                
                rc = s.listener_create(uri);
                enforce(rc == 0, "Listener create");        

                NNGTLS tls = NNGTLS(nng_tls_mode.NNG_TLS_MODE_SERVER);
                tls.set_auth_mode(nng_tls_auth_mode.NNG_TLS_AUTH_MODE_NONE);
                tls.set_own_cert(NNGTEST_SSL_CERT, NNGTEST_SSL_KEY);

                log(tls.toString());

                rc = s.listener_set_tls(&tls);
                enforce(rc == 0, "Listener set TLS");        

                rc = s.listener_start();
                log("RR: listening");
                enforce(rc == 0, "RR: Error listening socket");
                
                while(1){
                    auto str = s.receive!string();;
                    if(s.errno == 0){
                        log("RR: GOT["~(to!string(str.length))~"]: >"~str~"<");
                        if(str == "END"){
                            _ok = true;
                            break;
                        }
                    }else{
                        error("RR: Error string: " ~ nng_errstr(s.errno));
                    }                    
                }
                if(!_ok){
                    error("RR: Test stopped without normal end.");
                }
            } catch(Throwable e) {
                error(dump_exception_recursive(e, "RR: Receiver worker"));
            }
        }
    } // version(withtls)
 

    private:
        Thread[] workers;
        string uri;

}


