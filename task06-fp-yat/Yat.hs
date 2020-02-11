module Yat where  -- Вспомогательная строчка, чтобы можно было использовать функции в других файлах.
import Data.List
import Data.Maybe
import Data.Bifunctor
import Debug.Trace

-- В логических операциях 0 считается ложью, всё остальное - истиной.
-- При этом все логические операции могут вернуть только 0 или 1.

-- Все возможные бинарные операции: сложение, умножение, вычитание, деление, взятие по модулю, <, <=, >, >=, ==, !=, логическое &&, логическое ||
data Binop = Add | Mul | Sub | Div | Mod | Lt | Le | Gt | Ge | Eq | Ne | And | Or

-- Все возможные унарные операции: смена знака числа и логическое "не".
data Unop = Neg | Not

data Expression = Number Integer  -- Возвращает число, побочных эффектов нет.
                | Reference Name  -- Возвращает значение соответствующей переменной в текущем scope, побочных эффектов нет.
                | Assign Name Expression  -- Вычисляет операнд, а потом изменяет значение соответствующей переменной и возвращает его. Если соответствующей переменной нет, она создаётся.
                | BinaryOperation Binop Expression Expression  -- Вычисляет сначала левый операнд, потом правый, потом возвращает результат операции. Других побочных эффектов нет.
                | UnaryOperation Unop Expression  -- Вычисляет операнд, потом применяет операцию и возвращает результат. Других побочных эффектов нет.
                | FunctionCall Name [Expression]  -- Вычисляет аргументы от первого к последнему в текущем scope, потом создаёт новый scope для дочерней функции (копию текущего с добавленными параметрами), возвращает результат работы функции.
                | Conditional Expression Expression Expression -- Вычисляет первый Expression, в случае истины вычисляет второй Expression, в случае лжи - третий. Возвращает соответствующее вычисленное значение.
                | Block [Expression] -- Вычисляет в текущем scope все выражения по очереди от первого к последнему, результат вычисления -- это результат вычисления последнего выражения или 0, если список пуст.

type Name = String
type FunctionDefinition = (Name, [Name], Expression)  -- Имя функции, имена параметров, тело функции
type State = [(String, Integer)]  -- Список пар (имя переменной, значение). Новые значения дописываются в начало, а не перезаписываютсpя
type Program = ([FunctionDefinition], Expression)  -- Все объявленные функций и основное тело программы

showBinop :: Binop -> String
showBinop Add = "+"
showBinop Mul = "*"
showBinop Sub = "-"
showBinop Div = "/"
showBinop Mod = "%"
showBinop Lt  = "<"
showBinop Le  = "<="
showBinop Gt  = ">"
showBinop Ge  = ">="
showBinop Eq  = "=="
showBinop Ne  = "/="
showBinop And = "&&"
showBinop Or  = "||"

showUnop :: Unop -> String
showUnop Neg = "-"
showUnop Not = "!"

addTabs = intercalate "\n" . map ("\t"++) . lines
addSemicolon = intercalate ";\n" . lines

showExpression :: Expression -> String
showExpression (Number num)                               = show num
showExpression (Reference ref)                            = ref
showExpression (Assign name expr)                         = concat ["let ", name, " = ", showExpression expr, " tel"]
showExpression (BinaryOperation binop exprLeft exprRight) = concat ["(", 
                                                                    showExpression exprLeft,
                                                                    " ",
                                                                    showBinop binop,
                                                                    " ",
                                                                    showExpression exprRight,
                                                                    ")"]
showExpression (UnaryOperation unop expr)                 = showUnop unop ++ showExpression expr
showExpression (FunctionCall name exprs)                  = concat [name,
                                                                    "(",
                                                                    intercalate ", " (map showExpression exprs),
                                                                    ")"]
showExpression (Conditional condition exprTrue exprFalse) = concat ["if ",
                                                                    showExpression condition,
                                                                    " then ",
                                                                    showExpression exprTrue,
                                                                    " else ",
                                                                    showExpression exprFalse,
                                                                    " fi"]
showExpression (Block exprs)                              = concat ["{\n",
                                                                    concatMap
                                                                        (\ a -> "\t" ++ a ++ "\n") (lines (intercalate ";\n" (map showExpression exprs))),
                                                                    "}"]

showFunctionDefinition :: FunctionDefinition -> String
showFunctionDefinition (name, args, body) = concat ["func ",
                                                  name,
                                                  "(",
                                                  intercalate ", " args,
                                                  ") = ",
                                                  showExpression body]

-- Верните текстовое представление программы (см. условие).
showProgram :: Program -> String
showProgram (functions, body) = concatMap (\ f -> showFunctionDefinition f ++ "\n") functions ++ showExpression body

toBool :: Integer -> Bool
toBool = (/=) 0

fromBool :: Bool -> Integer
fromBool False = 0
fromBool True  = 1

toBinaryFunction :: Binop -> Integer -> Integer -> Integer
toBinaryFunction Add = (+)
toBinaryFunction Mul = (*)
toBinaryFunction Sub = (-)
toBinaryFunction Div = div
toBinaryFunction Mod = mod
toBinaryFunction Lt  = (.) fromBool . (<)
toBinaryFunction Le  = (.) fromBool . (<=)
toBinaryFunction Gt  = (.) fromBool . (>)
toBinaryFunction Ge  = (.) fromBool . (>=)
toBinaryFunction Eq  = (.) fromBool . (==)
toBinaryFunction Ne  = (.) fromBool . (/=)
toBinaryFunction And = \l r -> fromBool $ toBool l && toBool r
toBinaryFunction Or  = \l r -> fromBool $ toBool l || toBool r

toUnaryFunction :: Unop -> Integer -> Integer
toUnaryFunction Neg = negate
toUnaryFunction Not = fromBool . not . toBool

-- Если хотите дополнительных баллов, реализуйте
-- вспомогательные функции ниже и реализуйте evaluate через них.
-- По минимуму используйте pattern matching для `Eval`, функции
-- `runEval`, `readState`, `readDefs` и избегайте явной передачи состояния.

{- -- Удалите эту строчку, если решаете бонусное задание.
newtype Eval a = Eval ([FunctionDefinition] -> State -> (a, State))  -- Как data, только эффективнее в случае одного конструктора.

runEval :: Eval a -> [FunctionDefinition] -> State -> (a, State)
runEval (Eval f) = f

evaluated :: a -> Eval a  -- Возвращает значение без изменения состояния.
evaluated = undefined

readState :: Eval State  -- Возвращает состояние.
readState = undefined

addToState :: String -> Integer -> a -> Eval a  -- Добавляет/изменяет значение переменной на новое и возвращает константу.
addToState = undefined

readDefs :: Eval [FunctionDefinition]  -- Возвращает все определения функций.
readDefs = undefined

andThen :: Eval a -> (a -> Eval b) -> Eval b  -- Выполняет сначала первое вычисление, а потом второе.
andThen = undefined

andEvaluated :: Eval a -> (a -> b) -> Eval b  -- Выполняет вычисление, а потом преобразует результат чистой функцией.
andEvaluated = undefined

evalExpressionsL :: (a -> Integer -> a) -> a -> [Expression] -> Eval a  -- Вычисляет список выражений от первого к последнему.
evalExpressionsL = undefined

evalExpression :: Expression -> Eval Integer  -- Вычисляет выражение.
evalExpression = undefined
-} -- Удалите эту строчку, если решаете бонусное задание.

-- Реализуйте eval: запускает программу и возвращает её значение.

-- setValue []             _   _                         = undefined
setValue state key value = (key, value):state

getValue []             _                       = undefined
getValue (curVar:state) key | fst curVar == key = snd curVar
                            | otherwise         = getValue state key

getFunction []                             _                               = undefined
getFunction ((name, args, body):functions) targetName | name == targetName = (name, args, body)
                                                      | otherwise          = getFunction functions targetName

getFunctionName (name, _,    _   ) = name
getFunctionArgs (_,    args, _   ) = args
getFunctionBody (_,    _,    body) = body

evalFuncCall   state funcs name exprs        []             params = (state, snd funcRes)
                                                                     where funcRes = evalExpression (state ++ params) funcs (getFunctionBody (getFunction funcs name))

evalFuncCall   state funcs name (expr:exprs) (pName:pNames) params = funcRes
                                                                     where exprRes = evalExpression state funcs expr
                                                                           funcRes = evalFuncCall (fst exprRes) funcs name exprs pNames ((pName, snd exprRes):params)

evalExpression state funcs (Number num)                               = (state, num)

evalExpression state funcs (Reference ref)                            = (state, getValue state ref)

evalExpression state funcs (Assign name expr)                         = (setValue (fst res) name (snd res),
                                                                         snd res)
                                                                         where res = evalExpression state funcs expr

evalExpression state funcs (BinaryOperation binop exprLeft exprRight) = (fst resRight,
                                                                         toBinaryFunction binop (snd resLeft) (snd resRight))
                                                                         where resLeft  = evalExpression state         funcs exprLeft
                                                                               resRight = evalExpression (fst resLeft) funcs exprRight

evalExpression state funcs (UnaryOperation unop expr)                 = (fst res,
                                                                         toUnaryFunction unop (snd res))
                                                                         where res = evalExpression state funcs expr

evalExpression state funcs (FunctionCall name exprs)                  = evalFuncCall state funcs name exprs pNames []
                                                                        where pNames = getFunctionArgs(getFunction funcs name)

evalExpression state funcs (Conditional exprCond exprTrue exprFalse) | toBool (snd condRes) = trueRes
                                                                     | otherwise            = falseRes
                                                                     where condRes  = evalExpression state         funcs exprCond
                                                                           trueRes  = evalExpression (fst condRes) funcs exprTrue
                                                                           falseRes = evalExpression (fst condRes) funcs exprFalse

evalExpression state funcs (Block [])                                 = (state, 0)
evalExpression state funcs (Block [expr])                             = evalExpression state funcs expr
evalExpression state funcs (Block (expr:exprs))                       = othersRes
                                                                        where res       = evalExpression state     funcs expr
                                                                              othersRes = evalExpression (fst res) funcs (Block exprs)

eval :: Program -> Integer
eval (functions, expr) = snd (evalExpression [] functions expr)
