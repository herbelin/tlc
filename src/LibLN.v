(**************************************************************************
* TLC: A library for Coq                                                  *
* Library for locally nameless developments                               *
**************************************************************************)

Set Implicit Arguments.
From TLC Require Import LibList.
From TLC Require Export LibTactics LibProd LibLogic LibVar LibEnv.

Open Scope fset_scope.
Open Scope env_scope.


(* ********************************************************************** *)
(** ** Case analysis on variables and indices *)

(** --LATER: replace these specific tactics with the generic ones *)

(** [case_if_eq E F] performs a case analysis to test
    whether [E = F] or [E <> F]. It is used to implement
    the following two tactics. *)

Ltac case_if_eq_base E F H :=
  destruct (classicT (E = F)) as [H|H];
  [tryfalse; try subst E | tryfalse ].

Tactic Notation "case_if_eq" constr(E) constr(F) "as" ident(H) :=
  case_if_eq_base E F H.
Tactic Notation "case_if_eq" constr(E) constr(F) :=
  let C := fresh "C" in case_if_eq E F as C.

(** [case_nat] performs a case analysis to analyse a If-statement
    comparing two natural numbers for equality. The If-statement
    is searched for first in the hypotheses then it the goal. *)

Ltac case_if_eq_nat :=
  match goal with
  | H: context [classicT(?x = ?y :> nat)] |- _ => case_if_eq x y
  | |- context [classicT(?x = ?y :> nat)]      => case_if_eq x y
  end.

Tactic Notation "case_nat" := case_if_eq_nat.
Tactic Notation "case_nat" "~" := case_nat; auto_tilde.
Tactic Notation "case_nat" "*" := case_nat; auto_star.

(** [case_var] performs a case analysis to analyse a If-statement
    comparing two variables for equality. The If-statement
    is searched for first in the hypotheses then it the goal. *)

Ltac case_if_eq_var :=
  match goal with
  | H: context [classicT(?x = ?y :> var)] |- _ => case_if_eq x y
  | |- context [classicT(?x = ?y :> var)]      => case_if_eq x y
  end.

Tactic Notation "case_var" := case_if_eq_var; try solve [ notin_false ].
Tactic Notation "case_var" "~" := case_var; auto_tilde.
Tactic Notation "case_var" "*" := case_var; auto_star.


(* ********************************************************************** *)
(** ** Applying lemmas with quantification over cofinite sets *)

(** [apply_fresh_base] tactic is a helper to build tactics that apply an
  inductive constructor whose first argument should be instantiated
  by the set of names already used in the context. Those names should
  be returned by the [gather] tactic given in argument. For each premise
  of the inductive rule starting with an universal quantification of names
  outside the set of names instantiated, a subgoal with be generated by
  the application of the rule, and in those subgoal we introduce the name
  quantified as well as its proof of freshness. *)

Ltac apply_fresh_base_simple lemma gather :=
  let L0 := gather in let L := beautify_fset L0 in
  first [apply (@lemma L) | eapply (@lemma L)].

Ltac intros_fresh x :=
   first [
     let Fr := fresh "Fr" x in
     intros x Fr
  |  let x2 :=
       match goal with |- forall _:?T, _ =>
       match T with
       | var => fresh "y"
       | vars => fresh "ys"
       | list var => fresh "ys"
       | _ => fresh "y"
       end end in
     let Fr := fresh "Fr" x2 in
     intros x2 Fr ].

Ltac apply_fresh_base lemma gather var_name :=
  apply_fresh_base_simple lemma gather;
  try (match goal with
    | |- forall _:_, _ \notin _ -> _ => intros_fresh var_name
    | |- forall _:_, fresh _ _ _ -> _ => intros_fresh var_name
    end).

(** [exists_fresh_gen G y Fry] picks a variable [y] fresh from
    the current context. [Fry] is the name of the freshness
    hypothesis, and [G] is the local tactic [gather_vars]. *)

Ltac exists_fresh_gen G y Fry :=
  let L := G in exists L; intros y Fry.


(* ********************************************************************** *)
(** * Applying lemma modulo a simple rewriting *)

(** [do_rew] is used to perform the sequence:
    rewrite the goal, execute a tactic, rewrite the goal back *)

Tactic Notation "do_rew" constr(E) tactic(T) :=
  rewrite <- E; T; try rewrite E.

Tactic Notation "do_rew" "<-" constr(E) tactic(T) :=
  rewrite E; T; try rewrite <-  E.

Tactic Notation "do_rew" "*" constr(E) tactic(T) :=
  rewrite <- E; T; auto_star; try rewrite* E.
Tactic Notation "do_rew" "*" "<-" constr(E) tactic(T) :=
 rewrite E; T; auto_star; try rewrite* <- E.

(** [do_rew_2] is like [do_rew] but it rewrites twice *)

Tactic Notation "do_rew_2" constr(E) tactic(T) :=
  do 2 rewrite <- E; T; try do 2 rewrite E.

Tactic Notation "do_rew_2" "<-" constr(E) tactic(T) :=
  do 2 rewrite E; T; try do 2 rewrite <- E.

(** [do_rew_all] is like [do_rew] but rewrites as many times as possible *)

Tactic Notation "do_rew_all" constr(E) tactic(T) :=
  rewrite_all <- E; T; try rewrite_all E.

Tactic Notation "do_rew_all" "<-" constr(E) tactic(T) :=
  rewrite_all E; T; try rewrite_all <- E.


(* ********************************************************************** *)
(** ** Tactics for applying lemmas on empty environments *)

(** Tactic to apply an induction hypothesis modulo a rewrite of
  the associativity of the environment necessary to handle the
  inductive rules dealing with binders. [apply_ih_bind] is in
  fact just a syntactical sugar for [do_rew concat_assoc (eapply H)]
  which stands for
  [rewrite concat_assoc; eapply H; rewrite <- concat_assoc]. *)

Tactic Notation "apply_ih_bind" constr(H) :=
  do_rew concat_assoc (applys H).

Tactic Notation "apply_ih_bind" "*" constr(H) :=
  do_rew* concat_assoc (applys H).

(** Similar as the above, except in the case where there
  is also a map function, so we need to use [concat_assoc_map_push]
  for rewriting. *)

Tactic Notation "apply_ih_map_bind" constr(H) :=
  do_rew concat_assoc_map_push (applys H);
  try solve [ rewrite concat_assoc; reflexivity ].

Tactic Notation "apply_ih_map_bind" "*" constr(H) :=
  do_rew* concat_assoc_map_push (applys H);
  try solve [ rewrite concat_assoc; reflexivity ].

(** [clean_empty H] simplifies terms in H terms of the form
    [map f empty] and of the form [E & empty] *)

Tactic Notation "clean_empty" hyp(H) :=
  repeat (match type of H with context [map ?f empty] =>
    rewrite (map_empty f) in H end);
  repeat (match type of H with context [?E & empty] =>
    rewrite (concat_empty_r E) in H end).

(** [apply_empty] applies a lemma of the form "forall E:env, P E"
    in the particular case where E is empty. The tricky step is
    the simplification of "P empty" before the "apply" tactic is
    called, and this is necessary for Coq to recognize that the
    lemma indeed applies. *)

Ltac apply_empty_base H :=
  let M := fresh "TEMP" in
  lets M: (@H empty);
  specializes_vars M;
  clean_empty M;
  first [ apply M | eapply M | applys M ];
  clear M.

Tactic Notation "apply_empty" constr(H) :=
  apply_empty_base H.
Tactic Notation "apply_empty" "~" constr(H) :=
  apply_empty H; auto_tilde.
Tactic Notation "apply_empty" "*" constr(H) :=
  apply_empty H; auto_star.


(* ********************************************************************** *)
(** * Some results on lists *)

(** We use [List.nth] instead of [LibList.nth] so that we can
    have control over the default value returned in case of
    invalid index *)

Lemma list_map_nth : forall A (f : A -> A) (d : A) (l : list A) (n : nat),
  f d = d -> f (List.nth n l d) = List.nth n (LibList.map f l) d.
Proof using. induction l; introv E; destruct n; rew_listx; simpl; auto. Qed.

(** Property over lists of given length *)

#[global]
Hint Constructors Forall.

Definition list_for_n (A : Set) (P : A -> Prop) (n : nat) (L : list A) :=
  n = length L /\ Forall P L.

Lemma list_for_n_concat : forall (A : Set) (P : A -> Prop) n1 n2 L1 L2,
  list_for_n P n1 L1 ->
  list_for_n P n2 L2 ->
  list_for_n P (n1+n2) (L1 ++ L2).
Proof using.
  unfold list_for_n. introv [? ?] [? ?]. split.
  rew_list~.
  apply* Forall_app.
Qed.

#[global]
Hint Extern 1 (?n = length ?xs) =>
 match goal with H: list_for_n _ ?n ?xs |- _ =>
  apply (proj1 H) end.

#[global]
Hint Extern 1 (length ?xs = ?n) =>
 match goal with H: list_for_n _ ?n ?xs |- _ =>
  apply (sym_eq (proj1 H)) end.


(* ********************************************************************** *)
(** * Misc *)

(* Due to a parsing conflict between the syntax of tactics
   and the symbol [~:] which is used to write typing judgments
   in many developments, we need to rebind a few tactics in
   a slightly different way. *)

Tactic Notation "forwards" "~:" constr(E) :=
  forwards ~ : E.
Tactic Notation "tests" "~:" constr(E) :=
  tests ~ : E.

