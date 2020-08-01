/*
 * Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *      http://www.apache.org/licenses/LICENSE-2.0
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package chrism.sdsc.dataframe

import java.util.concurrent.ThreadLocalRandom
import java.{lang => jl}

import chrism.sdsc.Runner
import org.apache.spark.sql.{functions, DataFrame, SparkSession}
import org.apache.spark.sql.expressions.UserDefinedFunction

object DefineYourOwnFunctions extends Runner {

  private val to_boolean: UserDefinedFunction = functions.udf(toBoolean(_: jl.Integer))

  override def run(args: Array[String])(implicit spark: SparkSession): Unit = {
    // stubbed
    // Run the unit test
  }

  def applyUDFDataFrameAPI(
    df: DataFrame,
    intColumnName: String,
    convertedColumnName: Option[String] = None
  ): DataFrame =
    df.select(
      df.schema
        .map(_.name match {
          case n if n == intColumnName =>
            val converted_column = to_boolean(functions.col(n))
            convertedColumnName.map(converted_column.as).getOrElse(converted_column)
          case other => functions.col(other)
        }): _*)

  def applyUDFSQLStyle(
    df: DataFrame,
    intColumnName: String,
    convertedColumnName: Option[String] = None
  )(
    implicit
    spark: SparkSession
  ): DataFrame = {
    // Register `df` as a temp view.
    val view = generateViewName()
    df.createOrReplaceTempView(view)

    // Register the method `toBoolean` as a UDF to SparkSession.
    spark.udf.register("to_boolean", toBoolean(_: jl.Integer))

    val columnsToSelect = df.schema
      .map(_.name match {
        case n if n == intColumnName => s"to_boolean(`$n`) AS `${convertedColumnName.getOrElse(n)}`"
        case other                   => s"`$other`"
      })
      .mkString(", ")

    spark.sql(s"SELECT $columnsToSelect FROM `$view`")
  }

  /** Returns
    *   - true if 1
    *   - false if 0
    *   - null for all other values
    *
    * @param i an integer value to convert
    * @return 1 if true, 0 if false, else null
    */
  private def toBoolean(i: jl.Integer): jl.Boolean =
    i match {
      case nonNull if nonNull == 0 => false
      case nonNull if nonNull == 1 => true
      case _                       => null
    }

  private def generateViewName(): String = "temp_table_" + ThreadLocalRandom.current().nextLong(0L, Long.MaxValue)
}
