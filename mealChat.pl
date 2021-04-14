:- use_module(library(http/http_open)).
:- use_module(library(http/json)).

%-----------API---------------------
% reference to https://github.com/thibaultdewit/Interactive-Tour-Guide
% constants
root_url("https://www.themealdb.com/api/json/v1/").
api_key("1").
area_url("/filter.php?a=").
category_url("/filter.php?c=").
random_url("/random.php").
name_recipe_url("/search.php?s=").
sorry.
done.

%% choose(List, Elt) - chooses a random element
%% in List and unifies it with Elt.
choose([], _).
choose(List, Elt) :-
    length(List, Length),
    random(0, Length, Index),
    nth0(Index, List, Elt).

%% replace_substring(String, To_Replace, Replace_With, Result) 
%%      replace the to_replace with replace with in the result
replace_substring(StringIn, SepBy, SepWith, StringOut) :-
    split_string(StringIn, SepBy, "", List),
    atomics_to_string(List, SepWith, StringOut).

%% list_butlast delete the last item in the list
list_butlast([X|Xs], Ys) :-                 % use auxiliary predicate ...
   list_butlast_prev(Xs, Ys, X).            % ... which lags behind by one item

list_butlast_prev([], [], _).
list_butlast_prev([X1|Xs], [X0|Ys], X0) :-  
   list_butlast_prev(Xs, Ys, X1).           % lag behind by one

% set urls
% eg. https://www.themealdb.com/api/json/v1/1/filter.php?a=chinese
set_url_by_area(Atom, MealNames) :- 
	root_url(X),
    api_key(K),
	area_url(A),
	string_concat(X, K, Y),
    string_concat(Y, A, Z),
	string_concat(Z, Atom, Url),
    make_api_call(Url, MealNames).
    

% eg. https://www.themealdb.com/api/json/v1/1/filter.php?c=seafood
set_url_by_category(Atom, MealNames) :- 
	root_url(X),
    api_key(K),
	category_url(C),
	string_concat(X, K, Y),
    string_concat(Y, C, Z),
	string_concat(Z, Atom, Url),
    make_api_call(Url, MealNames).

% eg. https://www.themealdb.com/api/json/v1/1/search.php?s=Arrabiata
set_recipe_by_name(StrName, Recipe) :-
    root_url(X),
    api_key(K),
	name_recipe_url(C),
	string_concat(X, K, Y),
    string_concat(Y, C, Z),
	string_concat(Z, StrName, Url),
    make_api_call_recipe(Url, Recipe).

% eg. https://www.themealdb.com/api/json/v1/1/random.php
set_url_by_random(MealNames) :-
    root_url(X),
    api_key(K),
	random_url(C),
	string_concat(X, K, Y),
    string_concat(Y, C, Url),
    make_api_call(Url, MealNames).




% makes api request
make_api_call(URL, Ans) :-
	http_open(URL, In_stream, []),
	json_read_dict(In_stream, Dict),
	close(In_stream),
	json_to_meals(Dict, Meals),
    meals_to_mealnames(Meals, MealNames),
    choose(MealNames,Ans).

make_api_call_recipe(URL, Recipe) :-
	http_open(URL, In_stream, []),
	json_read_dict(In_stream, Dict),
	close(In_stream),
	json_to_meals(Dict, Meals),
    meals_to_recipe(Meals, Recipe).

% convert json to printable data

% convert json dictionary to a list of meals data
json_to_meals(Dict, Dict.meals).

% convert a list of meals data to a list of names
meals_to_mealnames([],[]).
meals_to_mealnames([H | T], [H.strMeal | Meals]) :-
    meals_to_mealnames(T, Meals).
meals_to_mealnames(null,sorry).

% convert a list of meals data to a list of recipe
meals_to_recipe([],[]).
meals_to_recipe([H | T], [H.strInstructions | Recipe]) :-
    meals_to_recipe(T, Recipe).
meals_to_recipe(null,sorry).


%%--------------NLP system------------
% build on to prof.Poole's class material

% A noun phrase is a determiner followed by adjectives followed
% by a noun followed by an optional modifying phrase:
noun_phrase(L0,L4,Entity) :-
    det(L0,L1,Entity),
    adjectives(L1,L2,Entity),
    noun(L2,L3,Entity),
    mp(L3,L4,Entity).
noun_phrase(L,L,_).


% A verb phrase is a adjectives followed
% by a verb followed by an optional modifying phrase:
verb_phrase(L0,L5,Entity) :-
    adjectives(L0,L2,Entity), 
    verb(L2,L3,Entity),
    noun_phrase(L3,L4,Entity),
    mp(L4,L5,Entity).
verb_phrase(L,L,_).

% Determiners (articles) are ignored in this oversimplified example.
% They do not provide any extra constraints.
det([the | L],L,_).
det([a | L],L,_).
det(L,L,_).


% adjectives(L0,L2,Entity) is true if 
% L0-L2 is a sequence of adjectives imposes Entity
adjectives(L0,L2,Entity) :-
    adj(L0,L1,Entity),
    adjectives(L1,L2,Entity).
adjectives(L,L,_).

% An optional modifying phrase / relative clause is either
% a noun_phrase followed by a verb_phrase or start with 'for'
% 'that' followed by a relation then a noun_phrase or
% nothing 
mp(L0,L2,Object) :-
    noun_phrase(L0,L1,Object),
    verb_phrase(L1,L2,Object).
mp([that|L0],L2,Object) :-
    noun_phrase(L0,L1,Object),
    verb_phrase(L1,L2,Object).
mp([for|L0],L1,Object) :-
    noun_phrase(L0,L1,Object).
mp([to|L0],L1,Object) :-
    verb_phrase(L0,L1,Object).
mp([with|L0],L1,Object) :-
    noun_phrase(L0,L1,Object).
mp(L,L,_).


% adj(L0,L1,Entity) is true if L0-L1 
% is an adjective that imposes entity
adj([X | L],L,MealNames) :- 
    area(X), 
    set_url_by_area(X, MealNames).
adj([random | L],L,MealNames) :- 
    set_url_by_random(MealNames).
adj([my | L],L,_).
    
% noun(L0,L1,Entity) is true if L0-L1 
% is an adjective that imposes entity
noun([X | L],L,MealNames) :- 
    category(X),
    set_url_by_category(X, MealNames).
noun([people | L],L,_).
noun([food | L],L,_).
noun(["I" | L],L,_).
noun([recipe | L],L,_).
noun([dish | L],L,_).
noun([meal | L],L,_).
noun([meals | L],L,_).
noun([you | L],L,_).
noun([me | L],L,_).


% verb is some possible word when asking, not determine true
verb([eat | L], L,_).
verb([drink | L], L,_).
verb([cook | L], L,_).
verb([make | L], L,_).
verb([do | L], L,_).
verb([can | L], L,_).
verb([have | L], L,_).
verb([suggest | L], L,_).
verb([help | L], L,_).
verb([give | L], L,_).


% question(Question,QR,Entity) is true if Query provides an answer about Entity to Question
question(['Is' | L0],L2,Entity) :-
    noun_phrase(L0,L1,Entity),
    mp(L1,L2,Entity).
question(['What',is | L0], L1, Entity) :-
    mp(L0,L1,Entity).
question(['What',is | L0],L1,Entity) :-
    noun_phrase(L0,L1,Entity).
question(['What',can,'I'| L0],L2,Entity) :-
    verb_phrase(L0,L2,Entity).
question(['What',do,'I' | L0],L2,Entity) :-
    verb_phrase(L0,L2,Entity).
question(['What',can | L0],L2,Entity) :-
    noun_phrase(L0,L2,Entity).
question(['What',do | L0],L2,Entity) :-
    noun_phrase(L0,L2,Entity).
question(['What' | L0],L2,Entity) :-
    mp(L0,L2,Entity).
question(['Give',me | L0], L2, Entity) :-
    noun_phrase(L0,L2,Entity). 
question(['Can',you | L0], L2, Entity) :-
    verb_phrase(L0,L2,Entity). 



question([recipe | _], _, done) :-
    ask_for_name. 

%-------------------------------how, directly give a recipe------------------------------------------------
question(['How',to,make| L0], _, done) :-
    list_butlast(L0,L1),
    ask_for_recipe(L1).

question(['How',to,cook| L0], _, done) :-
    list_butlast(L0,L1),
    ask_for_recipe(L1). 
question(['How',can,'I',cook| L0], _, done) :-
    list_butlast(L0,L1),
    ask_for_recipe(L1). 
question(['How',can,'I',cook| L0], _, done) :-
    list_butlast(L0,L1),
    ask_for_recipe(L1).
question(['Give',me,the,recipe,of | L0], _, done) :-
    list_butlast(L0,L1),
    ask_for_recipe(L1). 



%-------------------------------quitquit------------------------------------------------
question([A | _], _, done) :-
    member(A,['Q',quit,exit,ex,q,na,no,nope,'N']),
    ending_message. 

% ask(Q,A) gives answer A to question Q
ask(Q,A) :-
    question(Q,End,A),
    member(End,[[],['?'],['.'],['!']]).

reply(Re, Name) :- 
    member(Re,[[ye],[yes],[yeah],[ok],['Yes'],[y]]),
    replace_substring(Name,"'","%27",Nospace),
    replace_substring(Nospace," ","%20",Noquote),
    set_recipe_by_name(Noquote, Ans),
    q4(Name,Ans).

reply(Re, _) :- 
    member(Re,[[na],[no],[nope],[n],['No'],[],[quit],["Q"],[exit],[ex]]),
    ending_message. 




% ----------------------UI part----------------

start :-
    write("\n----Welcome to the Meal Recommender!----\n"),
     
    write("I can help you with: "), 
    write(" \n"),    
    write("     Suggest a meal with a given area and offer recipe if you want; \n"),
    write("     Suggest a meal with a given category and offer recipe if you want; \n"),
    write("     Suggest a meal for you randomly if you have no idea about what to cook; \n"),
    write("_____PLEASE ONLY INCLUDE ONE AREA/CATEGORY TO FILTER EACH TIME _____"),
    write(" \n\n"),
    write("Type your question below to ask me: \n"),
    q2.

q2 :-
    write(" "), flush_output(current_output),
    readln(Ln),
    ask(Ln,Ans), 
    write("\n"),
    write(Ans),
    q3(Ans).

ask_for_name :-
    write("\n Type the name of the meal: "), flush_output(current_output),
    readln(Ln),
    ask_for_recipe(Ln).

ask_for_recipe(MealNameList) :-
    atomics_to_string(MealNameList," ",StrName),
    replace_substring(StrName,"'","%27",Nospace),
    replace_substring(Nospace," ","%20",Noquote),
    set_recipe_by_name(Noquote, Ans),
    q4(StrName,Ans).

q3(done).
q3(Name) :-
    write("\n \n Do you want the recipe of this?  "), flush_output(current_output),
    readln(Ln),
    reply(Ln,Name).
    

q4(Name,Ans) :-
    write(" ----------------------------------------------------------- \n \n"),
    write("Here is the recipe of "),
    write(Name),
    write(" \n "),
    write(" \n "),
    write(Ans),
    intermediate_message.

intermediate_message :-
    write("\n\n Anything else I can help with? "),
    q2.

ending_message :-
    write("\n----Thank you for using Meal Planner!----\n").



/*
?- q(Ans).
Ask me: What can I cook for dessert?
Ans = dessert ;
false.

?- q(Ans).
Ask me: Give me a recipe for breakfast.
Ans = breakfast ;
false.

Some more questions:
What can I cook for dessert?
What do chinese people eat?
What do I eat for starter?
What can I make with lamb?

*/

%  The Database of Facts to be Queried

% category(C)is true if C is a category
category(beef).
category(breakfast).
category(chicken).
category(dessert).
category(goat).
category(lamb).
category(miscellaneous).
category(pasta).
category(pork).
category(seafood).
category(sode).
category(starter).
category(vegan).
category(vegetarian).

% area(A)is true if A is an area
area(american).
area(british).
area(canadian).
area(chinese).
area(dutch).
area(egyptian).
area(french).
area(greek).
area(indian).
area(irish).
area(italian).
area(jamaican).
area(japanese).
area(kenyan).
area(malaysian).
area(mexican).
area(moroccan).
area(polish).
area(portuguese).
area(russian).
area(spanish).
area(thai).
area(tunisian).
area(turkish).
area(vietnamese).

