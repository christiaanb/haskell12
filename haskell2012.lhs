\documentclass[conference,10pt]{IEEEtran}
\IEEEoverridecommandlockouts

\usepackage{ifthen}
%include lineno.fmt
\input{preamble.dem}
%include haskell2012.fmt

\begin{document}

\title{\soosim{}: Operating System and \\ Programming Language Exploration}

\author{\IEEEauthorblockN{Christiaan Baaij\thanks{Supported through the S(o)OS project, sponsored by the European Commission under FP7-ICT-2009.8.1, Grant Agreement No. 248465}, Jan Kuper}
\IEEEauthorblockA{Computer Architecture for Embedded Systems\\
Department of EEMCS, University of Twente\\
Postbus 217, 7500AE Enschede, The Netherlands\\
Email: \url{{c.p.r.baaij;j.kuper}@@utwente.nl}}
}

\maketitle

\begin{abstract}
\boldmath
\soosim{} is a simulator developed for the purpose of exploring operating system concepts and operating system modules.
The simulator provides a highly abstracted view of a computing system, consisting of computing nodes, and components that are concurrently executed on these nodes.
OS modules are subsequently modelled as components that progress as a result of reacting to two types of events: messages from other components, or a system-wide tick event.
Using this abstract view, a developer can quickly formalize assertions regarding the interaction between operating system modules and applications.

We developed a methodology on top of \soosim{} that enables the precise control of the interaction between a simulated application and the operating system.
Embedded languages are used to model the application once, and different interpretations of the embedded language constructs are used to observe specific aspects on application's execution.
The combination of \soosim{} and embedded languages facilitates the exploration of programming language concepts and their interaction with the operating system.
\end{abstract}

\section{Introduction}
Simulation is a commonly used tool in the exploration of many design aspects of a system: ranging from feasibility aspects to gathering performance information.
However, when tasked with the creation of new operating system concepts, and their interaction with the programmability of large-scale systems, existing simulation packages do not seem to have the right abstractions for fast design exploration\cite{cotson,omnet} (ref. Section~\ref{sec_related_work}).
The work we present in this paper has been created in the context of the S(o)OS project\cite{soos}.
The S(o)OS project aims to research OS concepts and specific OS modules, which aid in scalability of the complete software stack (both OS and application) on future many-core systems.
One of the key concepts of S(o)OS is that only those OS modules needed by a application thread, are actually loaded into the (local) memory of a Core / CPU on which the thread will run.
This execution environment differs from contemporary operating systems where every core runs a complete copy of the (monolithic) operating system.

A basic requirement that we thus have towards any simulator, are the facilities to straightforwardly simulate the instantiation of application threads and OS modules.
Aside from the fact that the S(o)OS-envisioned system will be dynamic as a result of loading OS modules on-the-fly; large-scale systems also tend to be dynamic in the sense that computing nodes can (permanently) disappear (failure), or appear (hot-swap).
Hence, we also require that our simulator facilitates the straightforward creation and destruction of computing elements.
Our current need for a simulator rests mostly in formalizing the S(o)OS concept, and examining the interaction between our envisioned OS modules and the application threads.
As such, being able to extract highly accurate performance figures from a simulated system is not a key requirement.
We do however wish to be able to observe all interactions among application threads and OS modules.
Additionally, we wish to be able to \emph{zoom in} on particular aspects of the behaviour of an application: such as memory access, messaging, etc.

This paper describes a new simulator, \emph{\soosim{}}, that meets the above requirements.
We elaborate on the main concepts of the simulator in Section~\ref{sec_soosim}, and show how OS modules interact with each other, and with the simulator.
In Section~\ref{sec_embedded_programming_environment} we describe the use of embedded languages for creation of applications running in the simulated environment.
The simulation engine, the graphical user interface, and embedded language environment are all written in the functional programming language Haskell\cite{haskell98};
this means that all code listings in this paper also show Haskell code.
Due to limitation in the number of pages, we are not be able to elaborate every Haskell notation; the code examples are intended to support the validity of the presented concepts.
We compare \soosim{} to existing simulation frameworks, and list other related work in Section~\ref{sec_related_work}.
We enumerate our experiences with \soosim{} in Section~\ref{sec_conclusions}, and discuss potential future work in Section~\ref{sec_future_work}.

\section{Abstract System Simulator}
\label{sec_soosim}
The purpose of \soosim{} is mainly to provide a platform that allows a developer to observe the interactions between OS modules and application threads.
It is for this reason that we have chosen to make the simulated hardware highly abstract.
In \soosim{}, the hardware platform is described as a set of nodes.
Each \emph{node} represents a physical computing object: such as a core, complete CPU, memory controller, etc.
Every node has a local memory of potentially infinite size.
The layout and connectivity properties of the nodes are not part of the system description.
If such a level of detail is required it would have to be modelled explicitly by the user.

Each \emph{node} hosts a set of components.
A \emph{component} represents an executable object: such as a thread, application, OS module, etc.
Components communicate with each other either using direct messaging, or through the local memory of a node.
Having both explicit messaging and shared memories, \soosim{} supports the two well known methods of communication.
Because multiple components can send messages to one component, all component have a message queue.
All components in a simulated system, even those hosted within the same node, are executed concurrently.
The simulator poses no restrictions as to which components can communicate with each other, nor to which node's local memory they can read from and write to.
A user of \soosim{} would have to model those restrictions explicitly if required.
A schematic overview of an example system can be seen in Figure~\ref{img_system}.

\def\svgwidth{\columnwidth}
\begin{figure}
\includesvg{system}
\caption{Abstracted System}
\label{img_system}
\vspace{-1.5em}
\end{figure}

The simulator progresses all components concurrently in one discrete step called a \hs{tick}.
During a \emph{tick}, the simulator passes the content that is at the head of the message queue of each individual component.
If the message queue of a component is empty, a component will be executed with a \emph{null} message.
If desired, a component can inform the simulator that it does not want to receive these \emph{null} messages.
In that case the component will not be executed by the simulator during a \emph{tick}.

\subsection{OS Component Descriptions}
Components of the simulated system are, like the simulator core, also described in the functional programming language Haskell.
This means that each component is described as a function.
In case of \soosim{}, such a function is not a simple algebraic function, but a function executed within the context of the simulator.
The Haskell parlance for such a computational context is a \emph{Monad}, the term we will use henceforth.
Because the function is executed within the monad, it can have \emph{side-effects} such as sending messages to other components, or reading the memory of a local memory.
In addition, the function can be temporarily suspended at (almost) any point in the code.
\soosim{} needs to be able to suspend the execution of a function so that it may emulate synchronous messaging between components, a subject we will further elaborate later on.

We describe a component as a function that, as its first argument, receives a user-defined internal state, and as its second argument a value of type \hs{SimEvent}.
The result of this function will be the (potentially updated) internal state.
Values of type \hs{SimEvent} can either be:
\begin{itemize}
  \item A message from another component.
  \item A \emph{null} message.
\end{itemize}
We thus have the following type signature for a component:
\numbersoff
\begin{code}
component :: state -> SimEvent -> SimM state
\end{code}
The \hs{SimM} annotation on the result type means that this function is executed within the simulator monad.
The user-defined internal state can be used to store any information that needs to perpetuate across simulator \emph{ticks}.

To include a component description in the simulator, the developer will have to create a so-called \emph{instance} of the \hs{ComponentIface} \emph{type-class}.
A \emph{type-class} in Haskell can be compared to an interface definition as those known in object-oriented languages.
An \emph{instance} of a \emph{type-class} is a concrete instantiation of such an interface.
The \hs{ComponentIface} requires the instantiation of the following values to completely define a component:

\begin{itemize}
  \item The initial internal state of the component.
  \item The unique name of the component.
  \item The monadic function describing the behaviour of the component.
\end{itemize}

We remark that we are aiming at a high level of abstraction for the behavioural descriptions of our OS modules, where the focus is mainly on the interaction with other OS modules and application threads.

\subsection{Interaction with the simulator}
Components have several functions at their disposal to interact with the simulator and consequently interact with other components.
The available functions are the following:
% \paragraph{\hs{registerComponent}}
% Register a component definition with the simulator.
% This means that an \emph{instance} of the \hs{CompIface} for this component must be defined.
\paragraph{\hs{createComponent}}
Instantiate a new component on a specified node. %; the component definition must be registered with the simulator.
\paragraph{\hs{invoke}}
Send a message to another component, and wait for the answer.
This means that whenever a component uses this function it will be (temporarily) suspended by the simulator.
Several simulator ticks might pass before the callee sends a response.
Once the response is put in the message queue of the caller, the simulator resumes the execution of the calling component.
Having this synchronization available obviates the need to specify the behaviour of a component as a finite state machine.
\paragraph{\hs{invokeAsync}}
Send a message to another component, and register a handler with the simulator to process the response.
Unlike \hs{invoke}, using this function will \emph{not} suspend the execution of the component.
\paragraph{\hs{respond}}
Send a message to another component as a response to an invocation.
\paragraph{\hs{yield}}
Inform the simulator that the component does not want to receive \emph{null} messages.
\paragraph{\hs{readMem}}
Read at a specified address of a node's local memory.
\paragraph{\hs{writeMem}}
Write a new value at a specified address of a node's local memory.
\paragraph{\hs{componentLookup}}
Lookup the unique identifier of a component on a specified node.
Components have two unique identifiers, their global \emph{name} (as specified in the \hs{CompIface} instance), and a \hs{ComponentId} that is a unique number corresponding to a specific instance of a component.
When you want to \emph{invoke} a component, you need to know the unique \hs{ComponentId} of the specific instance.
To give a concrete example, using the system of Figure~\ref{img_system} as our context: \emph{Thread(\#6)} wants to invoke the instance of the \emph{Memory Manager} that is running on the same Node (\#2).
As \emph{Thread(\#6)} was not involved with the instantiation of that OS module, it has no idea what the specific \hs{ComponentId} of the memory manager on Node \#2 is.
It does however know the unique global name of all memory managers, so it can use the \hs{componentLookup} function to find the \hs{Memory Manager} with ID \#5 that is running on Node \#2.

\subsection{Example OS Component: Memory Manager}
This subsection demonstrates the use of the simulator API, taking the \hs{Read} code-path of the memory manager module as an example.
In our case the memory manager takes care that the reads or writes of a global address end up in the correct node's local memory.
As part of its internal state the memory manager keeps a lookup table.
This lookup table states whether an address range belongs to the local memory of the node that hosts the memory manager, or whether that address is handled by a memory manager on another node.
An entry of the lookup table has the following datatype:
\begin{code}
data Entry = EntryC
  {  base   :: Int
  ,  range  :: Int
  ,  scrId  :: Maybe ComponentId
  }
\end{code}
The fields \hs{base} and \hs{range} together describe the memory address range defined by this entry.
The \hs{srcId} tells us whether the range is hosted on the node's local memory, or whether another memory manager is responsible for the address range.
If the value of \hs{scrId} is \hs{Nothing} the address is hosted on the node's local memory; if \hs{srcId} has the value \hs{Just cmpId}, the memory manager with ID \hs{cmpId} is responsible for the address range.

Listing~\ref{lst_read_logic_memory_manager} highlights the Haskell code for the read-logic of the memory manager.
Lines 1 and 2 show the type signature of the function defining the behaviour of the memory manager.
On line 3 we use pattern-matching, to match on a \hs{Message} event, binding the values of the ComponentId of the caller, and the message content, to \hs{caller} and \hs{content} respectively.
Because components can send any type of message to the memory manager, including types we do not expect, we \hs{unmarshal} the message content on line 4, and only continue when it is a \hs{Read} message (indicated by the vertical bar \hs{|}~).
If it is a \hs{Read} message, we bind the value of the address to the name \hs{addr}.
On line 6 we lookup the address range entry which encompasses \hs{addr}.
Line 7 starts a \hs{case}-statement discriminating on the value of the \hs{srcId} of the entry.
If the \hs{srcId} is \hs{Nothing} (line 8-11), we read the node's local memory using the \hs{readMem} function, \hs{respond} to the caller with the read value, and finally \hs{yield} to the simulator.
When the address range is handled by a \hs{remote} memory manager (line 12-15), we \hs{invoke} that specific memory manager module with the read request and wait for a response.
We remark that many simulator cycles might pass between the invocation and the return, as the \hs{remote} memory manager might be processing many requests.
Once we receive the value from the \hs{remote} memory manager, we \hs{respond} to the original caller forwarding the received value.
\begin{program}
\begin{code}
memoryManager :: MemState
  -> SimEvent
  -> SimM MemState
memoryManager s (Message caller content)
  | (Read addr) <- unMarshal content
  =  do
     let entry = addressLookup s addr
     case (srcId entry) of
       Nothing -> do
         addrVal <- readMem addr
         respond caller addrVal
         yield s
       Just remote -> do
         response <- invoke remote content
         respond caller response
         yield s
  | (Write addr val) <- unMarshal content
  = do
    ...
\end{code}
\caption{Read logic of the Memory Manager}
\label{lst_read_logic_memory_manager}
\end{program}

\subsection{Simulator GUI}
The state of a simulated system can be observed using the \soosim{} GUI, of which a screenshot is shown in Figure~\ref{fig_simulator_gui}.
The GUI allows you to run and step through a simulation at different speeds.
On the screenshot we see, at the top, the toolbar controlling the simulation, in the middle, a schematic overview of the simulated system in, and specific information belonging to a selected component at the bottom.
Different colours indicate whether a component is active, waiting for a response, or idle.
The \emph{Component Info} box shows both static and statistical information regarding a selected component.
Several statistics are collected by the simulator, including the number of simulation cycles spent in a certain state (active / idle / waiting), messages sent and received, etc.

These statistics can be used to roughly evaluate the performance bottlenecks in a system.
For example, when OS module 'A' has mostly active cycles, and components 'B'-'Z' are mostly waiting, one can check if components 'B'-'Z' were indeed communicating with 'A'.
If this happens to be the case, then 'A' is indeed a bottleneck in the system.
A general rule-of-thumb for a well performing system is when OS modules have many \emph{idle} cycles, and application threads have mostly \emph{active} cycles.
\begin{figure*}
\includegraphics[width=18cm]{images/gui.png}
\caption{Simulator GUI}
\label{fig_simulator_gui}
\vspace{-1.5em}
\end{figure*}

\section{Embedded Programming Environment}
\label{sec_embedded_programming_environment}
One of the reasons to develop \soosim{} is to observe the interaction between applications and the operating system.
Additionally, we want to explore programming language concepts intended for parallel and concurrent programming, and how they impact the entire software stack.
For this purpose we have developed a methodology on top of \soosim{}, that uses embedded languages to specify the applications.
Our methodology consists of two important aspects:

\begin{itemize}
  \item The use of embedded (programming) languages to define an application.
  \item Defining different interpretations for such an application description, allowing a developer to observe different aspects of the execution of an application.
\end{itemize}

\subsection{Embedded Languages}
An \emph{embedded language} is a language that can be used from within another language or application.
The language that is embedded is called the \emph{object} language, and the language in which the \emph{object} language is embedded is called the \emph{host} language.
Because the \emph{object} language is \emph{embedded}, the \emph{host} language has complete control over any terms / expressions defined within this \emph{object} language.
There are multiple ways of representing embedded languages, for example as a string, which must subsequently be parsed within the \emph{host} language.

Haskell has been used to host many kinds of embedded (domain-specific) languages\cite{haskell_embedded}.
The standard approach in Haskell is not to represent \emph{object} terms as strings, but instead use data-types and functions.
To make this idea more concrete, we present the recursive Fibonacci function, defined using one of our self-defined \emph{embedded} functional languages, in Listing~\ref{lst_fib}.

\begin{program}
%format fun = "\mathbf{fun}"
%format app = "\mathbf{app}"
%format fix = "\mathbf{fix}"
%format if_ = "\mathbf{if\_}"
%format lt  = "\mathbf{lt}"
%format drf = "\mathbf{drf}"
%format nv  = "\mathbf{nv}"
%format seq = "\mathbf{seq}"
%format `seq` = "\ `\mathbf{seq}`\ "
\begin{code}
fib :: Symantics repr => repr (IntT :-> IntT)
fib = fix $ \f ->
  fun $ \n ->
    nv 0 $ \n1 ->
    nv 0 $ \n2 ->
    nv 0 $ \n3 ->
      n1 =: n `seq`
      if_ (lt (drf n1) 2)
        1
        (  n2 =: (app f (drf n1 - 1)) `seq`
           n3 =: (app f (drf n1 - 2)) `seq`
           drf n2 + drf n3
        )
\end{code}
\caption{Call-by-Value Fibbonaci}
\label{lst_fib}
\end{program}

All functions printed in \textbf{bold} are language constructs in our \emph{embedded language}.
Additionally the \hs{=:} operator is also one of our \emph{embedded} language constructs; the numeric operators and literals are also overloaded to represent embedded terms.
To give some insight as to how Listing~\ref{lst_fib} represents the recursive Fibonacci function, we quickly elaborate each of the lines.

The type annotation on line 1 tells us that we have a function defined at the \emph{object}-level (\hs{:->}) with an \emph{object}-level integer (\hs{IntT}) as argument and an \emph{object}-level integer (IntT) as result.
Line 2 creates a fixed-point over \hs{f}, making the recursion of our embedded Fibonacci function explicit.
On line 3 we define a function parameter \hs{n} using the \hs{fun} construct.
We remark that we use Haskell binders to represent binders in our \emph{embedded language}.
On line 4-6 we introduce three mutable references, all having the initial integer value of 0.
We assign the value of \hs{n} to the mutable reference \hs{n1} on line 7.
On line 8 we check if the dereferenced value of \hs{n1} is less than 2; if so we return 1 (line 9); otherwise we assign the value of the recursive call of \hs{f} with \hs{(n1 - 1)} to \hs{n2}, and assign the value of the recursive call of \hs{f} with \hs{(n1 - 2)} to \hs{n3}.
We subsequently return the addition of the dereferenced variables \hs{n2} and \hs{n3}.

We must confess that there is some syntactic overhead as a result of using Haskell functions and datatypes to specify the language constructs of our \emph{embedded} language; as opposed to using a string representation.
However, we have consequently saved ourselves from many implementation burdens associated with embedded languages:
\begin{itemize}
  \item We do not have to create a parser for our language.
  \item We can use Haskell bindings to represent bindings in our own language, avoiding the need to deal with such \emph{tricky} concepts as: symbol tables, free variable calculation, and capture-free substitution.
  \item We can use Haskell's type system to represent types in our embedded language: meaning we can use Haskell's type-checker to check expressions defined in our own embedded language.
\end{itemize}

\subsection{Interpreting an Embedded Language}
We mentioned the concept of \emph{type-classes} when we discussed the process of including a component description in the simulator.
Following the \emph{final tagless}\cite{final_tagless_embedding} encoding of embedded languages in Haskell, we use a type-class to define the language constructs of our mini functional language with mutable references.
A partial specification of the \hs{Symantics} (a pun on \emph{syntax} and \emph{semantics}) type-class, defining our \emph{embedded language}, is shown in Listing~\ref{lst_embedded_language_interface}.

\begin{program}
\begin{code}
class Symantics repr where
  fun  :: (repr a -> repr b) -> repr (a :-> b)
  app  :: repr (a :-> b) -> repr a -> repr b
\end{code}
$\ \ \ .\ .\ .$
\begin{code}
^^ drf   :: repr (Ref a) -> repr a
^^ (=:)  :: repr (Ref a) -> repr a -> repr Void
\end{code}
\caption{Embedded Language - Partial Definition}
\label{lst_embedded_language_interface}
\end{program}

We read the types of our language definition constructs as follows:
\begin{itemize}
  \item \hs{fun} takes a \emph{host}-level function from \hs{object}-type \hs{a} to \hs{object}-type \hs{b} (\hs{repr a -> repr b}), and returns an \emph{object}-level function from \hs{a} to \hs{b} (\hs{a :-> b}).
  \item \hs{app} takes an \emph{object}-level function from \hs{a} to \hs{b}, and applies this function to an \emph{object}-term of type \hs{a}, returning an \emph{object}-term of type \hs{b}.
  \item \hs{drf} dereferences an \hs{object}-term of type "reference of" \hs{a} (written in Haskell as \hs{Ref a}), returning an \emph{object}-term of type \hs{a}.
  \item \hs{(=:)} is operator that updates an \emph{object}-term of type "reference of" \hs{a}, with a new \emph{object}-value of type \hs{a}, returning an \emph{object}-term of type \hs{Void}.
\end{itemize}

To give a desired interpretation of an application described by our embedded language we simply have to implement an instance of the \hs{Symantics} type-class.
These interpretations include pretty-printing the description, determining the size of expression, evaluating the description as if it were a normal Haskell function, etc.

In the context of this paper we are however interested in \emph{observing} (specific parts of) the execution of an application inside the \soosim{} simulator.
As a running example, we show part of an instance definition that observes the invocations of the memory manager module upon dereferencing and updating mutable references:

\begin{program}
\begin{code}
instance Symantics SimM where
  ...

  drf x = do
    i     <- foo x
    mmId  <- componentLookup "MemoryManager"
    invoke mmId (marshal (Read i))

  x =: y = do
    i     <- foo x
    v     <- bar y
    mmId  <- componentLookup "MemoryManager"
    invoke mmId (mashal (Write i v))
\end{code}
\caption{Observing Memory Access}
\label{lst_observing_memory_access}
\end{program}

We explained earlier that the simulator \emph{monad} (\hs{SimM}) should be seen as a computational context in which a function is executed.
By making our simulator monad the computational \hs{instance} (or environment) of our embedded language definition, we can now run the applications defined with our embedded language inside the \soosim{} simulator.
Most language constructs of our embedded language will be implemented in such a way that they behave like their Haskell counterpart.
The constructs where we made minor adjustments are the \hs{drf} and (=:) constructs, which now enact communication with our \emph{Memory Manager} OS module.
By using the \hs{invoke} function, our application descriptions are also suspended whenever they dereference or update memory locations, as they have to wait for a response from the memory manager.
Using the \soosim{} GUI, we can now observe the communication patterns between the applications described in our embedded language, and our newly created OS module.

\subsection{Further Extensions and Interpretations}
The use cases of embedded languages in the context of our simulation framework extend far beyond the example given in the previous subsection.
We can for example easily extend our language definition with constructs for parallel composition, and introduce blocking mutable references for communication between threads.
An initial interpretation (in the form of a type-class instance) could then be sequential execution, allowing for the simple search of algorithmic bugs in the application.
A second instance could then use the Haskell counterparts for parallel composition and block mutable variables to mimic an actual concurrent execution.
A third instance could then interact with OS modules inside a \soosim{} simulated system, allowing a developer to observe the interaction between our new language constructs and the operating system.

We said earlier that one of the interpretations of an embedded language description could be a pretty-printed string-representation.
Following up on the idea of converting a description to a datatype, we can also interpret our application description as an abstract syntax tree or even a dependency graph.
Such a dependency graph could then be used in another instances of our embedded language that facilitates the automatic parallel execution of independent sub-expressions.
Again, we can hook up such an instance to our simulator monad, and observe the effects of the distribution of computation and data, as facilitated by our simulated operating system.

\section{Related Work}
\label{sec_related_work}
COTSon\cite{cotson} is a full system simulator, using an emulator (such as SimNow) for the processor architecture.
It allows a developer to execute normal x86-code in a simulated environment.
COTSon is far too detailed for our needs, and does not facilitate the easy exploration of a complete operating system.

OMNeT++\cite{omnet} is a C++-based discrete event simulator for modelling distributed or parallel system.
Compared to \soosim{}, OMNeT++ does not allow the straightforward creation of new modules, meaning the distribution of modules is static.
OMNeT++ is thus not meeting our simulation needs to dynamically instantiate new OS modules and application threads.

House\cite{house} is an operating system built in Haskell; it uses a Haskell run-time system allowing direct execution on bare metal.
OS modules are executed with the \hs{Hardware} monad, comparable to our \hs{Simulator} monad, allowing direct interaction with real hardware.
Consequently, OS modules in House must be implemented in full detail, meaning this approach is not suitable for our exploration needs.

Barrelfish\cite{barrelfish} is an OS in which embedded languages are used, amongst other purposes, to define driver interfaces.
These embedded languages are also implemented in Haskell.
The approach used in Barrelfish is however to create parsers for their embedded languages so that they may have a \emph{nicer} syntax, inducing an additional implementation burden.

\section{Conclusions}
\label{sec_conclusions}
Although the \soosim{} simulator is still considered work in progress, it has already allowed us to formalize the interactions between the different OS modules devised within the S(o)OS\cite{soos} project.
We believe that this is the strength of our simulator's approach: the quick exploration and formalization of system concepts.
Fast exploration is achieved by the highly abstracted view of \soosim{} on the hardware / system.
However, having to actually program all our OS modules forces us to formalize the interactions within the system; exposing any potential flaw not discovered by an informal (text-based) description of the operating system.

By using embedded languages to program applications that run in our simulated environment, we attain complete control of its execution.
By using specific interpretations of our embedded language, we can easily observe specific parts (such as memory access) of an application's execution.
Using Haskell functions to specify our embedded language constructs saves us from a high implementation burden usually associated with the creation of the tools / compilers for programming languages.

\section{Future Work}
\label{sec_future_work}
At the moment, the simulation core of \soosim{} is a single-threaded.
We expect that as we move to the simulation of systems with 10's to 100's of computing nodes, that the single threaded approach can become a performance bottleneck.
Although individual components are susceptible for parallel execution, the communication between components is problematically non-deterministic.
We plan to use Haskell's implementation of software transactional memory (STM) to safely deal with the non-deterministic communication and still achieve parallel execution.

We will additionally explore the use of embedded languages, in the domain of operating system and programming language design, further.
Within the context of the S(o)OS project, we intend to add both explicit parallel composition to our embedded language definition, and implicit parallel interpretation of data-independent sub-expressions.
We also intend to implement software transactional memory constructs, and investigate their interaction with the operating system.

\section*{Acknowledgements}
The authors would like to thank Ivan Perez for the design and implementation of the \soosim{} GUI.

\bibliographystyle{IEEEtran}
\bibliography{haskell2012}

\end{document}
