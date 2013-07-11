module Csound.Render(
    render    
) where

import qualified Data.IntMap as IM

import Csound.Exp
import Csound.Exp.Options
import Csound.Render.Pretty
import Csound.Render.Instr
import Csound.Render.Options
import Csound.Render.Channel

import Csound.Exp.Tuple(Out(..), outArity)
import Csound.Exp.GE
import Csound.Exp.SE(execSE)

render :: (Out a) => CsdOptions -> GE a -> IO String
render opt ge = fmap (show . renderHistory (nchnls ge) opt) $ flip execGE opt $ do
    _ <- saveAlwaysOnInstr . execSE . masterOuts =<< ge
    _ <- saveAlwaysOnInstr . execSE =<< clearGlobals 
    return ()
    where 
        nchnls = outArity . proxy 
        proxy :: GE a -> a
        proxy = undefined

renderHistory :: Int -> CsdOptions -> History -> Doc
renderHistory numOfChnls options history = ppCsdFile 
    -- flags
    (renderFlags options) 
    -- instr 0
    (renderInstr0 numOfChnls (midis history) (globalsSoFar $ globals history) options)
    -- orchestra
    (renderOrc $ instrs history)
    -- scores
    (renderSco $ scos history)
    -- strings
    (ppMapTable ppStrset $ strIndex history)
    -- ftables
    (ppTotalDur (getDuration history) $$ (ppMapTable ppTabDef $ tabIndex history))    
    
renderSco :: Scos -> Doc
renderSco x = vcat $ fmap ppAlwayson $ alwaysOnInstrs x

renderOrc :: Instrs -> Doc
renderOrc x = (vcatMap renderSource $ instrSources x) $$ (vcatMap renderMixer $ instrMixers x)
    where getMixerNotes instrId = (fmap renderNotes $ mixerNotes x) IM.! (instrIdCeil instrId)
          
          renderSource = uncurry renderInstr    
          renderMixer  (instrId, expr) = ppInstr instrId $
               ppFreeChnStmt
            $$ getMixerNotes instrId
            $$ renderInstrBody expr

renderNotes :: LowLevelSco -> Doc
renderNotes notes = vcat $ fmap (\(instrId, evt) -> ppEvent instrId evt chnVar) notes

