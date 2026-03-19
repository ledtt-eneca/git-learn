#!/bin/bash

mkdir git-demo && cd git-demo
git init
git config user.name "Demo"
git config user.email "demo@example.com"

# Коммиты в main
echo "# My App" > README.md
git add . && git commit -m "init: project init"

echo "version = '1.0'" > config.py
git add . && git commit -m "feat: add config"

cat > app.py << 'EOF'
def hello():
    print("Hello!")
EOF
git add . && git commit -m "feat: add hello"

cat >> app.py << 'EOF'

def goodbye():
    print("Goodbye!")
EOF
git add . && git commit -m "feat: add goodbye"

# Ветка feature/auth — ответвляется от второго коммита
# (создаёт "расхождение" с main — нужно для демо merge/rebase)
git checkout -b feature/auth HEAD~2

cat > auth.py << 'EOF'
def login(user, pwd):
    pass
EOF
git add . && git commit -m "feat: login stub"

cat >> auth.py << 'EOF'

def logout(user):
    pass
EOF
git add . && git commit -m "feat: logout stub"

echo "# TODO: validate token" >> auth.py
git add . && git commit -m "fix: add TODO"

echo "debug = True" >> auth.py
git add . && git commit -m "WIP"

git checkout main

# Проверяем
echo ""
echo "=== Готово. Граф репозитория: ==="
git log --oneline --graph --all


# ============================================================
# [ЧАСТЬ 1] Объекты, индекс, три зоны, refs, HEAD, ~^
# ============================================================

# --- Внутри .git/ ---
ls .git/
cat .git/HEAD               # "ref: refs/heads/main"
cat .git/refs/heads/main    # SHA последнего коммита

# --- Три зоны: рабочая папка / индекс / репозиторий ---
echo "## новая строчка" >> README.md

git status                  # Changes not staged — в рабочей папке
git diff                    # рабочая папка vs индекс

git add README.md
git status                  # Changes to be committed — в индексе
git diff                    # пусто: рабочая папка == индекс
git diff --staged            # индекс vs HEAD — вот что пойдёт в коммит

# Убираем из индекса, не трогая файл
git reset HEAD README.md
git status                  # снова unstaged
git checkout -- README.md   # вернуть файл к HEAD

# --- Адресация: HEAD~N и SHA ---
git log --oneline
# main:
#   abc4 feat: add goodbye  ← HEAD
#   abc3 feat: add hello    ← HEAD~1
#   abc2 feat: add config   ← HEAD~2
#   abc1 init: project init ← HEAD~3

git show HEAD               # последний коммит
git show HEAD~1             # предпоследний
git show HEAD~2:config.py   # как выглядел config.py два коммита назад

# SHA вместо HEAD — одно и то же:
# git show abc3             ← то же что git show HEAD~1

# --- Ветки и HEAD ---
git branch -v               # список веток с SHA
cat .git/HEAD               # ref: refs/heads/main
cat .git/refs/heads/main    # SHA = то что показывал git rev-parse HEAD
cat .git/refs/heads/feature/auth  # SHA кончика feature/auth


# ============================================================
# [ЧАСТЬ 2] Ветвление — создание веток, merge, rebase
# ============================================================

# --- Создать ветку и увидеть расхождение ---
git log --oneline --graph --all
# Видно: main и feature/auth расходятся от общего предка

# --- Fast-forward merge ---
# Создаём ветку где main не ушёл вперёд
git checkout -b demo/hotfix
echo "# hotfix" >> README.md
git add . && git commit -m "fix: hotfix"

git log --oneline --graph --all   # demo/hotfix впереди main, нет расхождения

git checkout main
git merge demo/hotfix             # fast-forward: просто двигает указатель
git log --oneline --graph --all   # нет merge-коммита, история линейная

git branch -d demo/hotfix

# --- Merge с merge-коммитом ---
# Создаём ситуацию где оба ответвились и пошли по-разному
git checkout -b demo/feature
echo "feature line" >> app.py
git add . && git commit -m "feat: feature work"

git checkout main
echo "# main update" >> README.md
git add . && git commit -m "docs: main update"

git log --oneline --graph --all   # расхождение: main и demo/feature

git merge demo/feature            # откроется редактор для сообщения merge-коммита
git log --oneline --graph --all   # merge-коммит с двумя родителями

git branch -d demo/feature

# --- Rebase ---
git checkout feature/auth
git log --oneline --graph --all   # feature/auth отстала от main

# Rebase: перекладываем коммиты feature/auth поверх main
git rebase main
git log --oneline --graph --all   # линейная история, новые хеши у коммитов feature/auth

git checkout main


# ============================================================
# [ЧАСТЬ 4] Команды и сценарии
# ============================================================

# --- git stash ---

git checkout feature/auth

echo "# работа в процессе" >> app.py
git status                  # есть незакоммиченные изменения

# Без stash переключиться нельзя (или git предупредит)
# git checkout main         ← может отказать

git stash                   # спрятать
git status                  # чисто
git checkout main
# ... делаем что нужно ...
git checkout feature/auth
git stash pop               # достать обратно
git status                  # изменения вернулись

# Именованные stash
git stash push -m "WIP: auth logic"
echo "// UI fix" >> README.md
git stash push -m "WIP: readme fix"

git stash list
# stash@{0}: WIP: readme fix
# stash@{1}: WIP: auth logic

# pop = apply + drop: достаёт и удаляет из стека
git stash pop stash@{1}

# apply: достаёт но ОСТАВЛЯЕТ в стеке (можно применить в нескольких ветках)
git stash apply stash@{0}   # изменения вернулись, stash@{0} ещё в списке
git stash list              # stash@{0} никуда не делся
git stash drop stash@{0}    # удалить вручную когда больше не нужен

# push с путём: спрятать только конкретный файл
git stash push app.py -m "WIP: app only"
git stash list
git stash drop              # удалить последний (stash@{0})

git checkout -- .           # откатить несохранённые изменения


# --- git cherry-pick ---

git checkout main
git log feature/auth --oneline
# WIP
# fix: add TODO    ← вот этот хотим в main
# feat: logout stub
# feat: login stub

# SHA из git log — обязателен (HEAD указывает на main, не на feature)
PICK=$(git log feature/auth --oneline | grep "fix: add TODO" | awk '{print $1}')
echo "cherry-pick: $PICK"

git cherry-pick $PICK
git log --oneline           # новый коммит с другим SHA, то же содержимое

# Отменить cherry-pick если не нравится результат
git reset --hard HEAD~1     # убрать последний коммит (тот который cherry-pick)

# Несколько коммитов:
# git cherry-pick sha1 sha2
# Диапазон (sha_start не включается):
# git cherry-pick sha_start..sha_end


# --- git revert ---

git log --oneline
# abc4 feat: add goodbye  ← HEAD
# abc3 feat: add hello    ← HEAD~1
# abc2 feat: add config   ← HEAD~2

# Отменить последний коммит (безопасно — создаёт новый коммит-отмену)
git revert HEAD --no-edit
git log --oneline           # появился "Revert ..." коммит
git show HEAD               # смотрим что он делает

# Отменить конкретный коммит по SHA (не обязательно последний):
# git revert abc2 --no-edit

# Важно: revert HEAD ≠ revert abc4 в общем случае!
# Если нужно отменить не последний — всегда используйте SHA


# --- git reset ---

git checkout feature/auth
git log --oneline
# WIP             ← HEAD
# fix: add TODO   ← HEAD~1
# feat: logout stub ← HEAD~2
# feat: login stub  ← HEAD~3

# --soft: склеить последние 3 коммита
# HEAD~3 = коммит "feat: login stub" — на него и переезжаем
git reset --soft HEAD~3
# Вариант через SHA: git reset --soft <sha_login_stub>

git status                  # все изменения в staged
git log --oneline           # остался только "feat: login stub"
git commit -m "feat: auth (login + logout + fix)"
git log --oneline           # один аккуратный коммит вместо трёх

# --mixed (default): убрать из staged
echo "debug_flag = True" > debug.py
git add .
git status                  # debug.py в staged

git reset HEAD debug.py     # убрать только один файл
# git reset HEAD            # убрать всё из staged
# git reset                 # то же самое

git status                  # debug.py untracked, изменения не потеряны
rm debug.py

# --hard: откатить всё (агент/IDE что-то сломал)
echo "# AI был здесь" >> app.py
echo "# AI был здесь" >> config.py
git status                  # два изменённых файла

git reset --hard HEAD       # всё вернулось к HEAD, изменения потеряны
git status                  # чисто
git diff                    # пусто

# --hard: откат на N коммитов назад
git log --oneline
# Вариант 1: HEAD~2 — на два назад
git reset --hard HEAD~2
# Вариант 2: SHA напрямую — одно и то же
# git reset --hard <sha>

git log --oneline           # два коммита ушли из ветки
git reflog                  # но они живы в reflog!


# --- git rebase -i ---

git checkout feature/auth
git log --oneline
# Должно быть примерно:
#   WIP             ← HEAD    (= HEAD~0)
#   fix: add TODO   ← HEAD~1
#   feat: logout stub ← HEAD~2
#   feat: login stub  ← HEAD~3
#   feat: add config  ← HEAD~4 (общий предок с main, НЕ входит в rebase)

# Открываем редактор для последних 4 коммитов:
# HEAD~4 = коммит ДО наших изменений (не включается в редактор)
# > git rebase -i HEAD~4
# Вариант через SHA предка: git rebase -i <sha_add_config>
# Автонахождение точки ветвления: git rebase -i $(git merge-base HEAD main)

# В редакторе меняем (коммиты сверху — старые, снизу — новые):
#   pick  feat: login stub       ← оставить
#   fixup fix: add TODO          ← склеить с login, убрать сообщение
#   pick  feat: logout stub      ← оставить
#   drop  WIP                    ← удалить

# После сохранения:
git log --oneline           # два аккуратных коммита вместо четырёх
# Хеши НОВЫЕ — git пересоздал коммиты

# Если что-то пошло не так во время rebase:
# git rebase --abort          ← отменить, вернуться к исходному состоянию
# После завершения если передумали:
# git reset --hard ORIG_HEAD  ← ORIG_HEAD хранит состояние до rebase


# ============================================================
# [ОЧИСТКА] после митапа
# ============================================================
# cd ..
# rm -rf git-demo
# rm -rf fake-remote.git
# rm -rf colleague
