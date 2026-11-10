# Reborn utilise Input::E pour la touche turbo, constante absente du binding
# Input du port Switch. On fournit une touche neutre (F5) pour ne pas planter.
module Input
  E = F5 unless const_defined?(:E)
end
