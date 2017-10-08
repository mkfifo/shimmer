
module SMR.Core.World where
import Data.IORef


-- | World state for evaluation
data World w
        = World
        { -- | Generator for nominal variables.
          worldNomGen   :: !(IORef Integer)

          -- | User state
        , worldUser     :: w }


-- | Initialize a new world.
worldInit :: w -> IO (World w)
worldInit w
 = do   refNomGen       <- newIORef 0
        return  $ World
                { worldNomGen   = refNomGen
                , worldUser     = w }
