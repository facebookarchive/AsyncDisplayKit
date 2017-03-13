document.addEventListener("DOMContentLoaded", function() {
	var swiftButtons = document.getElementsByClassName("swiftButton");
	var objectiveCButons = document.getElementsByClassName("objcButton");
	var objcCodes = document.getElementsByClassName("objcCode");
	var swiftCodes = document.getElementsByClassName("swiftCode");

	var totalCodeSections = swiftButtons.length;
	for(var i = 0; i < totalCodeSections; i++) {
	    swiftButtons[i].onclick = function () {
	    	for (var i = 0; i < totalCodeSections; i++) {
				swiftCodes[i].classList.remove("hidden");
				objcCodes[i].classList.add("hidden");
				objectiveCButons[i].classList.remove("active");
				swiftButtons[i].classList.add("active");
	    	};
    	}

	    objectiveCButons[i].onclick = function () {
	    	for (var i = 0; i < totalCodeSections; i++) {
				swiftCodes[i].classList.add("hidden");
				objcCodes[i].classList.remove("hidden");
				objectiveCButons[i].classList.add("active");
				swiftButtons[i].classList.remove("active");
	    	};
    	}
	}
});