{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

module Actus.Utility.YearFraction
  ( yearFraction,
  )
where

import Actus.Domain (ActusFrac (..))
import Actus.Domain.ContractTerms (DCC (..))
import Data.Text (pack)
import Data.Time
  ( Day,
    LocalTime (..),
    TimeOfDay (..),
    addLocalTime,
    diffDays,
    fromGregorian,
    gregorianMonthLength,
    isLeapYear,
    toGregorian,
  )
import Die (die)

yearFraction :: ActusFrac a => DCC -> LocalTime -> LocalTime -> Maybe LocalTime -> a
yearFraction dcc x y o = fromRational $ yearFraction' dcc (localDay x) (localDay $ clipToMidnight y) (localDay <$> o)

yearFraction' :: DCC -> Day -> Day -> Maybe Day -> Rational
yearFraction' DCC_A_AISDA startDay endDay _
  | startDay <= endDay =
    let (d1Year, _, _) = toGregorian startDay
        (d2Year, _, _) = toGregorian endDay
        d1YearFraction = (if isLeapYear d1Year then 366 else 365)
     in if d1Year == d2Year
          then fromInteger (diffDays endDay startDay) / d1YearFraction
          else
            let d2YearFraction = (if isLeapYear d2Year then 366 else 365)
                d1YearLastDay = fromGregorian (d1Year + 1) 1 1
                d2YearLastDay = fromGregorian d2Year 1 1
                firstFractionDays = toRational (diffDays d1YearLastDay startDay)
                secondFractionDays = toRational (diffDays endDay d2YearLastDay)
             in (firstFractionDays / d1YearFraction)
                  + (secondFractionDays / d2YearFraction)
                  + toRational d2Year - toRational d1Year - 1
  | otherwise =
    0.0
yearFraction' DCC_A_360 startDay endDay _
  | startDay <= endDay =
    let daysDiff = toRational (diffDays endDay startDay) in daysDiff / 360.0
  | otherwise =
    0.0
yearFraction' DCC_A_365 startDay endDay _
  | startDay <= endDay =
    let daysDiff = toRational (diffDays endDay startDay) in daysDiff / 365.0
  | otherwise =
    0.0
yearFraction' DCC_E30_360ISDA _ _ Nothing = die "DCC_E30_360ISDA requires maturity date"
yearFraction' DCC_E30_360ISDA startDay endDay (Just maturityDate)
  | startDay <= endDay =
    let (d1Year, d1Month, d1Day) = toGregorian startDay
        (d2Year, d2Month, d2Day) = toGregorian endDay
        d1ChangedDay =
          if isLastDayOfMonth d1Year d1Month d1Day then 30 else d1Day
        d2ChangedDay =
          if isLastDayOfMonth d2Year d2Month d2Day
            && not (endDay == maturityDate && d2Month == 2)
            then 30
            else d2Day
     in ( 360.0
            * toRational (d2Year - d1Year)
            + 30.0
            * toRational (d2Month - d1Month)
            + toRational (d2ChangedDay - d1ChangedDay)
        )
          / 360.0
  | otherwise =
    0.0
yearFraction' DCC_E30_360 startDay endDay _
  | startDay <= endDay =
    let (d1Year, d1Month, d1Day) = toGregorian startDay
        (d2Year, d2Month, d2Day) = toGregorian endDay
        d1ChangedDay = if d1Day == 31 then 30 else d1Day
        d2ChangedDay = if d2Day == 31 then 30 else d2Day
     in ( 360.0
            * toRational (d2Year - d1Year)
            + 30.0
            * toRational (d2Month - d1Month)
            + toRational (d2ChangedDay - d1ChangedDay)
        )
          / 360.0
  | otherwise =
    0.0
yearFraction' dcc _ _ _ =
  die . pack $ "Unsupported day count convention: " ++ show dcc

isLastDayOfMonth :: Integer -> Int -> Int -> Bool
isLastDayOfMonth year month day = day == gregorianMonthLength year month

-- | Advance to midnight, if one second before midnight - see note in ACTUS specification (2.8. Date/Time)
clipToMidnight :: LocalTime -> LocalTime
clipToMidnight lt@LocalTime {..} | localTimeOfDay == TimeOfDay 23 59 59 = addLocalTime 1 lt
clipToMidnight lt = lt
