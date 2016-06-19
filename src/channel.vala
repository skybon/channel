using Gee ;
using GLib ;

public errordomain ChannelError {
    CLOSED
}

public interface Channel<G>{
    public abstract void put(G v) ;
    public abstract G recv() ;
    public abstract void close() ;

}

public class BufferedChannel<G>: GLib.Object, Channel<G>{
    private GLib.Mutex m ;
    private Gee.LinkedList<G> data ;
    private signal void changed() ;

    private bool is_closed ;
    public int max_size ;

    public void put(G v) {
        var exitMutex = GLib.Mutex () ;
        var cb_id = GLib.Value (typeof (ulong)) ;

        cb_id.set_ulong (this.changed.connect (() => {
            this.m.lock( ) ;
            try {
                if( this.is_closed ){
                    throw new ChannelError.CLOSED ("") ;
                }
                if( this.max_size == -1 || this.data.size < this.max_size ){
                    if( this.data.offer_tail (v)){
                        this.disconnect (cb_id.get_ulong ()) ;
                        exitMutex.unlock () ;
                    }
                }
            } finally {
                this.m.unlock () ;
            }
        })) ;

        exitMutex.lock( ) ;
        this.changed () ;
        exitMutex.lock( ) ;
        exitMutex.unlock () ;
    }

    public G recv () {
        G v = null ;

        var exitMutex = GLib.Mutex () ;
        var cb_id = GLib.Value (typeof (ulong)) ;

        cb_id.set_ulong (this.changed.connect (() => {
            this.m.lock( ) ;
            try {
                if( this.data.size > 0 ){
                    v = this.data.poll_head () ;
                    this.disconnect (cb_id.get_ulong ()) ;
                    exitMutex.unlock () ;
                } else if( this.is_closed ){
                    throw new ChannelError.CLOSED ("") ;
                }
            } finally {
                this.m.unlock () ;
            }
        })) ;

        exitMutex.lock( ) ;
        this.changed () ;
        exitMutex.lock( ) ;
        exitMutex.unlock () ;

        return v ;
    }

    public void close() {
        this.m.lock( ) ;
        this.is_closed = true ;
        this.m.unlock () ;
    }

    public BufferedChannel (int ? size = null) {
        this.data = new Gee.LinkedList<G>() ;
        if( size != null && size > 0 ){
            this.max_size = size ;
        } else {
            this.max_size = -1 ;
        }
    }
}
