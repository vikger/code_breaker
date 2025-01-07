var ws;
var state;

function getColor(name) {
    switch (name) {
    case "black": return "rgb(0,0,0)";
    case "green": return "rgb(0,255,0)";
    case "blue": return "rgb(0,0,255)";
    case "red": return "rgb(255,0,0)";
    case "white": return "rgb(255,255,255)";
    case "yellow": return "rgb(255,255,0)";
    }
}

function State() {
    this.step = 0;
    this.guess = [];
};

State.prototype.put = function(color) {
    if (this.step < 4) {
        this.step++;
        this.guess.push(color);
    } else {
        this.step = 1;
        this.guess = [color];
    }
};

State.prototype.sendGuess = function() {
    if (this.step == 4)
        send({name: document.getElementById("name").value, guess: this.guess});
};

State.prototype.update = function() {
    guess1 = document.getElementById("guess1");
    guess2 = document.getElementById("guess2");
    guess3 = document.getElementById("guess3");
    guess4 = document.getElementById("guess4");
    if (this.step >= 1) {
        guess1.style.background = getColor(this.guess[0]);
    } else {
        guess1.style.background = "transparent";
    }
    if (this.step >= 2) {
        guess2.style.background = getColor(this.guess[1]);
    } else {
        guess2.style.background = "transparent";
    }
    if (this.step >= 3) {
        guess3.style.background = getColor(this.guess[2]);
    } else {
        guess3.style.background = "transparent";
    }
    if (this.step >= 4) {
        guess4.style.background = getColor(this.guess[3]);
    } else {
        guess4.style.background = "transparent";
    }
};

function send(message) {
    console.log("send: ", message);
    ws.send(JSON.stringify(message));
};

function connect() {
    const hostname = document.location.href.split("/").slice(2).join("/");
    if (ws) {
        ws.close();
    }
    var schema = (location.href.split(":")[0] == "https") ? "wss" : "ws";
    ws = new WebSocket(schema + "://" + hostname + "ws");
    console.log(ws);

    ws.onmessage = function(message){
        console.log("message", message.data);
    }
}

$(document).ready(function(){
    connect();
    state = new State();
    document.getElementById("black").style.background = getColor("black");
    $("#black").on("click", function(event) {
        state.put("black");
        state.update();
    });
    document.getElementById("green").style.background = getColor("green");
    $("#green").on("click", function(event) {
        state.put("green");
        state.update();
    });
    document.getElementById("blue").style.background = getColor("blue");
    $("#blue").on("click", function(event) {
        state.put("blue");
        state.update();
    });
    document.getElementById("red").style.background = getColor("red");
    $("#red").on("click", function(event) {
        state.put("red");
        state.update();
    });
    document.getElementById("white").style.background = getColor("white");
    $("#white").on("click", function(event) {
        state.put("white");
        state.update();
    });
    document.getElementById("yellow").style.background = getColor("yellow");
    $("#yellow").on("click", function(event) {
        state.put("yellow");
        state.update();
    });
    $("#guess").on("click", function(event) {
        state.sendGuess();
    });
});
