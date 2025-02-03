BigInt.prototype.toJSON = function() { return this.toString()+"n" }

export class WTagUtil {

    static dehibonize ( data ) {
        if( Array.isArray(data) && data.length == 2 ){
            if(typeof data[1] == "number" || typeof data[1] == "bigint"){
                return data[1];
            } else {
                switch(data[0]){
                    case "*":
                        return data[1];
                        break;
                    case "i32":
                    case "i64":
                        return parseInt(data[1]);
                        break;
                    case "f32":
                    case "f64":
                        return parseFloat(data[1]);
                        break;
                    case "big":
                        /*
                        let a = Uint8Array.from(atob(data[1].substring(1)), c => c.charCodeAt(0));
                        let v = new DataView(a.buffer);
                        switch(a.length){
                            case 8:
                                return v.getBigUint64(0);
                                break;
                            case 4:
                                return v.getUint32(0);
                                break;
                            case 2:    
                                return v.getUint16(0);
                                break;
                            case 1:    
                                return v.getUint8(0);
                                break;
                            default:
                                return a;
                                break;
                        } 
                        */
                        return data[1];
                        break;
                    case "time":
                        return new Date(data[1]);
                        break;
                    default:
                        return data;
                        break;
                }
            }
        }
        if(Array.isArray(data)){
            return data.map(WTagUtil.dehibonize);
        }
        if(data == null){
            return data;
        }
        if(typeof data === 'object'){
            return Object.keys(data).reduce(function(result, key) {
                result[key] = WTagUtil.dehibonize(data[key])
                return result
                }, {});
        }            
        return data;
    }

    static base64URLdecode(str) {
        const base64Encoded = str.replace(/-/g, '+').replace(/_/g, '/');
        const padding = str.length % 4 === 0 ? '' : '='.repeat(4 - (str.length % 4));
        const base64WithPadding = base64Encoded + padding;
        return atob(base64WithPadding)
    }

    static base64URLencode(str) {
        const bstr = btoa(str)
            .replace(/\+/g, '-')
            .replace(/\//g, '_')
            .replace(/=+$/, '');
        return bstr + (bstr.length % 4 === 0 ? '' : '='.repeat(4 - (bstr.length % 4)));
    }

}
