{-# LANGUAGE OverloadedStrings #-}
module SMR.Source.Pretty where
import SMR.Core.Exp.Base
import Data.Monoid
import Data.Text                                (Text)
import Data.Text.Lazy.Builder                   (Builder)
import qualified Data.Text.Lazy.Builder         as B
import qualified Data.Vector                    as V


-- Class ----------------------------------------------------------------------
class Build a where
 build  :: a -> Builder

instance Build Text where
 build tx = B.fromText tx


parens :: Builder -> Builder
parens bb
 = "(" <> bb <> ")"


-- Decl -----------------------------------------------------------------------
buildDecl
        :: (Build s, Build p)
        => Decl s p -> Builder
buildDecl dd
 = case dd of
        DeclMac n xx
         -> "@" <> B.fromText n <> " = " <> buildExp CtxTop xx <> ";\n"

        DeclSet n xx
         -> "+" <> B.fromText n <> " = " <> buildExp CtxTop xx <> ";\n"


-- Exp ------------------------------------------------------------------------
data Ctx
        = CtxTop        -- ^ Top level context.
        | CtxFun        -- ^ Functional expression in an an application.
        | CtxArg        -- ^ Argument expression in an application.
        deriving Show


buildExp
        :: (Build s, Build p)
        => Ctx -> Exp s p -> Builder
buildExp ctx xx
 = case xx of
        XRet vs
         -> let go []             = ">"
                go (x : [])       = buildExp CtxTop x  <> ">"
                go (x1 : x2 : xs) = buildExp CtxTop x1 <> ", " <> go xs
            in  go (V.toList vs)

        XRef r    -> buildRef r

        XVar n 0  -> B.fromText n
        XVar n d  -> B.fromText n <> "^" <> B.fromString (show d)

        XApp x1 x2
         -> let exp     = buildExp CtxFun x1 <> " " <> buildExp CtxArg x2
            in case ctx of
                CtxArg  -> parens exp
                _       -> exp

        XKey k1 x2
         -> let exp     = buildKey k1 <> " " <> buildExp CtxArg x2
            in  case ctx of
                 CtxArg -> parens exp
                 _      -> exp

        XAbs vs x
         -> let go []        = ". "
                go (p1 : []) = buildParam p1 <> ". "
                go (p1 : ps) = buildParam p1 <> " " <> go ps
                exp          = "\\" <> go (V.toList vs) <> buildExp CtxTop x
            in  case ctx of
                 CtxArg -> parens exp
                 CtxFun -> parens exp
                 _      -> exp


        XSub train x
         |  V.length train == 0  -> buildExp ctx x
         |  otherwise
         -> buildTrain train <> "." <> buildExp CtxTop x



buildParam :: Param -> Builder
buildParam pp
 = case pp of
        PParam n PVal    -> B.fromText n
        PParam n PExp    -> "~" <> B.fromText n


buildKey :: Key -> Builder
buildKey kk
 = case kk of
        KBox    -> "##box"
        KRun    -> "##run"
        KSeq    -> "##seq"
        KTag    -> "##tag"


-- Train ----------------------------------------------------------------------
buildTrain  :: (Build s, Build p) => Train s p -> Builder
buildTrain cs
 = go (V.toList cs)
 where  go []           = ""
        go (c : cs)     = go cs <> buildCar c


buildCar :: (Build s, Build p) => Car s p -> Builder
buildCar cc
 = case cc of
        CSim snv        -> buildSnv snv
        CRec snv        -> "[" <> buildSnv snv <> "]"
        CUps ups        -> buildUps ups


-- Snv ------------------------------------------------------------------------
buildSnv  :: (Build s, Build p) => Snv s p -> Builder
buildSnv (SSnv vs)
 = "[" <> go (V.toList $ V.reverse vs) <> "]"
 where  go []   = ""
        go (b : [])     = buildSnvBind b
        go (b : bs)     = buildSnvBind b <> ", " <> go bs


buildSnvBind :: (Build s, Build p) => SnvBind s p -> Builder
buildSnvBind ((name, bump), xx)
 | bump == 0
 = B.fromText name
 <> "=" <> buildExp CtxTop xx

 | otherwise
 =  B.fromText name <> "^" <> B.fromString (show bump)
 <> "=" <> buildExp CtxTop xx


-- Ups ------------------------------------------------------------------------
buildUps :: Ups -> Builder
buildUps (UUps vs)
 = "{" <> go (V.toList $ V.reverse vs) <> "}"
 where  go []   = ""
        go (b : [])     = buildUpsBump b
        go (b : bs)     = buildUpsBump b <> ", " <> go bs


buildUpsBump :: UpsBump -> Builder
buildUpsBump ((name, bump), inc)
 | bump == 0
 = B.fromText name
 <> "=" <> B.fromString (show inc)

 | otherwise
 =  B.fromText name <> "^" <> B.fromString (show bump)
 <> "=" <> B.fromString (show inc)


-- Ref ------------------------------------------------------------------------
buildRef :: (Build s, Build p) => Ref s p -> Builder
buildRef rr
 = case rr of
        RMac n  -> "@" <> B.fromText n
        RSet n  -> "+" <> B.fromText n
        RSym s  -> "%" <> build s
        RPrm p  -> "#" <> build p
