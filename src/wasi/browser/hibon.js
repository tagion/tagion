export class HiBON {
  #instance;


	set instance(val) {
        console.log("Instance set ", val);
		this.#instance = val;
        console.log("Instance this ", this);
	}


	createHiBON(ptr) {
	  this.#instance.exports.tagion_hibon_create(ptr);
	}


}
