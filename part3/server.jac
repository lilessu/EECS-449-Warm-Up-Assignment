import:py from mtllm.llms {Ollama}
glob llm = Ollama(model_name='tinyllama');

import:jac from rag {RagEngine}
glob rag_engine:RagEngine = RagEngine();

node Router {
    can 'route the query to the appropriate task type'
    classify(message:'query from the user to be routed.':str) -> ChatType by llm(method="Reason", temperature=0.0);
}

walker interact {
    has message: str;
    has session_id: str;

    can init_session with `root entry {
         visit [-->](`?Session)(?id == self.session_id) else {
            session_node = here ++> Session(id=self.session_id, chat_history=[], status=1);
            print("Session Node Created");

            visit session_node;
        }
    }
}

node Session {
    has id: str;
    has chat_history: list[dict];
    has status: int = 1;

    can 'Respond to message using chat_history as context and agent_role as the goal of the agent'
    llm_chat(
        message:'current message':str,
        chat_history: 'chat history':list[dict],
        agent_role:'role of the agent responding':str,
        context:'retrieved context from documents':list
    ) -> 'response':str by llm();

    can chat with interact entry {
        self.chat_history.append({"role": "user", "content": here.message});
        response = infer(message=here.message, chat_history=self.chat_history) spawn root;
        self.chat_history.append({"role": "assistant", "content": response.response});

        report {
            "response": response.response
        };
    }
}

walker infer {
    has message:str;
    has chat_history: list[dict];

    can init_router with `root entry {
        visit [-->](`?Router) else {
            router_node = here ++> Router();
            router_node ++> RagChat();
            router_node ++> QAChat();
            router_node ++> CapChat();
            visit router_node;
        }
    }

    can route with Router entry {
        classification = here.classify(message = self.message);
        visit [-->](`?Chat)(?chat_type==classification);
    }
}

enum ChatType {
    RAG : 'Need to use Retrievable information in specific documents to respond' = "RAG",
    QA : 'Given context is enough for an answer' = "user_qa",
    CAP: 'Prompt is in all capital letters' = 'CAP'
}




node Chat {
    has chat_type: ChatType;
}

node QAChat :Chat: {
    has chat_type: ChatType = ChatType.QA;

    can respond with infer entry {
        print("QAChat: Generating response for message:", here.message);
        
        try {
            # Call LLM to generate a response
            here.response = respond_with_llm(
                here.message, 
                here.chat_history, 
                agent_role="You are a conversation agent designed to help users with their queries"
            );
            print("LLM response in QAChat:", here.response);
        } except Exception as e {
            # Handle any errors during the LLM interaction
            print("Error in QAChat, fallback response used:", str(e));
            here.response = "Sorry, I couldn't process your request.";
        }
    }
}

node RagChat :Chat: {
    has chat_type: ChatType = ChatType.RAG;

    can respond with infer entry {
        print("RagChat: Retrieving context and generating response for message:", here.message);
        
        try {
            # Retrieve context from the rag_engine
            data = rag_engine.get_from_chroma(query=here.message);
            print("Context retrieved from documents:", data);
            
            # Generate response using the LLM
            here.response = respond_with_llm(
                here.message, 
                here.chat_history, 
                "You are a conversation agent designed to help users with their queries based on the documents provided", 
                data
            );
            print("LLM response in RagChat:", here.response);
        } except Exception as e {
            # Handle any errors during the context retrieval or LLM interaction
            print("Error in RagChat, fallback response used:", str(e));
            here.response = "Sorry, I couldn't process your request.";
        }
    }
}


node CapChat :Chat: {
    has chat_type: ChatType = ChatType.CAP;

    can respond with infer entry {
        print("CapChat: Generating response in all caps for message:", here.message);
        
        try {
            # Generate response using the LLM in all capital letters
            here.response = respond_with_llm(
                here.message, 
                here.chat_history, 
                agent_role="YOU ARE A CONVERSATION AGENT DESIGNED TO RESPOND TO USER PROMPTS, BUT IN ALL CAPITAL LETTERS."
            );
            print("LLM response in CapChat:", here.response);
        } except Exception as e {
            # Handle any errors during the LLM interaction
            print("Error in CapChat, fallback response used:", str(e));
            here.response = "SORRY, I COULDN'T PROCESS YOUR REQUEST.";
        }
    }
}
