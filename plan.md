# Plan

+ Intro: Parameterbinding in Depth
+ The Binding Process
  + Positional vs. Explicit
  + Splatting
  + Dynamic Parameters
  + From Pipeline
  + ParameterSets

+ The Type Conversion
  + Native Conversion
  + Type Converter
  + Parameter Classes

+ Analyzing the parameter binding process
+ Extra: Tab Completion

> Notes

Conversion Details

+ LanguagePrimitives.cs:
  + 251ff: ConversionRank, which governs sequence
  + 1610ff: for the Type Process