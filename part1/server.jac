walker interact {
    can return_message with `root entry {
        report {
            "response": "Hello, world!"
        };
    }
}

walker interact_with_body {
    has name: str;

    can return_message with `root entry {
        report {
            "response": "Hello, " + self.name + "!!!!"
        };
    }
}


walker interact_with_body2 {
    has name: str;
    has name2: str;

    can return_message with `root entry {
        report {
            "response": "Hello, " + self.name + " and " + self.name2
        };
    }
}

walker mathWalker {
    has inputNum: str;

    can return_message with `root entry {
        report {
            "response": "New number is: " + self.inputNum + "1" + "!!!!"
        };
    }
}
